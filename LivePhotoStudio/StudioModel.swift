import AVKit
import Photos
import PhotosUI
import SwiftUI

@MainActor
final class StudioModel: ObservableObject {
    enum Activity {
        case importing, converting, saving

        var label: String {
            switch self {
            case .importing: "Video importeren…"
            case .converting: "Live Photo maken…"
            case .saving: "Opslaan in Foto’s…"
            }
        }
    }

    @Published private(set) var video: ImportedVideo?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var resources: LivePhotoResources?
    @Published private(set) var livePhoto: PHLivePhoto?
    @Published private(set) var previewError: String?
    @Published private(set) var activity: Activity?
    @Published private(set) var didSave = false
    @Published var error: String?
    @Published private(set) var frameFraction: Double?

    var busy: Bool { activity != nil }
    var chosenFrame: CMTime? {
        guard let video else { return nil }
        return frameFraction.map { video.frameTime(at: $0) } ?? video.defaultFrame
    }

    func importPhotos(_ item: PhotosPickerItem) async {
        await importVideo {
            guard let file = try await item.loadTransferable(type: ImportedFile.self) else {
                throw StudioError.importUnavailable
            }
            return file
        }
    }

    func importFiles(_ source: URL) async {
        await importVideo {
            try await Task.detached(priority: .userInitiated) {
                try ImportedFile.copy(from: source, coordinate: true)
            }.value
        }
    }

    private func importVideo(_ loadFile: () async throws -> ImportedFile) async {
        guard !busy else { return }
        activity = .importing
        defer { activity = nil }
        player?.pause()
        do {
            let file = try await loadFile()
            do {
                let imported = try await ImportedVideo(file: file)
                let previous = video?.file.directory
                resetResult()
                frameFraction = nil
                player?.replaceCurrentItem(with: nil)
                video = imported
                player = AVPlayer(playerItem: AVPlayerItem(asset: imported.asset))
                previous?.remove()
            } catch {
                file.directory.remove()
                throw error
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectFrame(_ fraction: Double) {
        guard !busy, let video else { return }
        frameFraction = fraction
        player?.pause()
        player?.seek(to: video.frameTime(at: fraction), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func resetFrame() {
        guard !busy else { return }
        frameFraction = nil
        if let chosenFrame {
            player?.seek(to: chosenFrame, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func editFrame() {
        guard !busy else { return }
        resetResult()
    }

    func convert() async {
        guard !busy, let video, let chosenFrame else { return }
        activity = .converting
        defer { activity = nil }
        player?.pause()
        resetResult()
        do {
            let resources = try await LivePhotoConverter.convert(video, at: chosenFrame)
            self.resources = resources
            do {
                livePhoto = try await PhotoLibrary.preview(of: resources)
            } catch {
                previewError = error.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        guard !busy, !didSave, let resources else { return }
        activity = .saving
        defer { activity = nil }
        do {
            try await PhotoLibrary.save(resources)
            didSave = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resetResult() {
        livePhoto = nil
        resources?.directory.remove()
        resources = nil
        previewError = nil
        didSave = false
    }
}
