import AVFoundation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct WorkingDirectory: Sendable {
    let url: URL

    private static let root: Result<URL, Error> = Result {
        let parent = URL.cachesDirectory.appending(path: "LivePhotoStudio", directoryHint: .isDirectory)
        let manager = FileManager.default
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let current = parent.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try manager.createDirectory(at: current, withIntermediateDirectories: false)
        for entry in (try? manager.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? [] {
            if entry != current { try? manager.removeItem(at: entry) }
        }
        return current
    }

    init() throws {
        url = try Self.root.get().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

struct ImportedFile: Transferable, Sendable {
    let url: URL
    let directory: WorkingDirectory
    let displayName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copy(from: received.file)
        }
    }

    static func copy(from source: URL, coordinate: Bool = false) throws -> Self {
        let directory = try WorkingDirectory()
        do {
            let fileExtension = source.pathExtension.isEmpty ? "mov" : source.pathExtension
            let destination = directory.url.appending(path: "video").appendingPathExtension(fileExtension)
            if coordinate {
                let hasAccess = source.startAccessingSecurityScopedResource()
                defer { if hasAccess { source.stopAccessingSecurityScopedResource() } }

                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                var copyResult: Result<Void, Error>?
                coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { readableURL in
                    copyResult = Result { try FileManager.default.copyItem(at: readableURL, to: destination) }
                }
                if let coordinationError { throw coordinationError }
                guard let copyResult else { throw StudioError.importUnavailable }
                try copyResult.get()
            } else {
                try FileManager.default.copyItem(at: source, to: destination)
            }
            return Self(url: destination, directory: directory, displayName: source.lastPathComponent)
        } catch {
            directory.remove()
            throw error
        }
    }
}

struct ImportedVideo {
    let file: ImportedFile
    let asset: AVURLAsset
    let videoTrack: AVAssetTrack
    let duration: CMTime
    let videoRange: CMTimeRange
    let presentationSize: CGSize
    let hasAudio: Bool

    init(file: ImportedFile) async throws {
        let asset = AVURLAsset(url: file.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = try await asset.load(.duration)
        guard duration.isNumeric, duration > .zero, try await asset.load(.isPlayable) else {
            throw StudioError.invalidVideo
        }
        let tracks = try await asset.loadTracks(withMediaType: .video)
        var enabled: [AVAssetTrack] = []
        for track in tracks {
            if try await track.load(.isEnabled) { enabled.append(track) }
        }
        guard !enabled.isEmpty else { throw StudioError.invalidVideo }
        guard enabled.count == 1, let track = enabled.first else { throw StudioError.multipleVideoTracks }
        let formats = try await track.load(.formatDescriptions)
        let supported: Set<FourCharCode> = [kCMVideoCodecType_H264, kCMVideoCodecType_HEVC, 0x68657631]
        guard !formats.isEmpty, formats.allSatisfy({ supported.contains(CMFormatDescriptionGetMediaSubType($0)) }) else {
            throw StudioError.unsupportedCodec
        }
        let range = try await track.load(.timeRange)
        guard range.duration.isNumeric, range.duration > .zero else { throw StudioError.invalidVideo }
        let transform = try await track.load(.preferredTransform)
        let dimensions = CMVideoFormatDescriptionGetPresentationDimensions(
            formats[0], usePixelAspectRatio: true, useCleanAperture: true
        )
        let rect = CGRect(origin: .zero, size: dimensions).applying(transform)
        guard rect.width > 0, rect.height > 0 else { throw StudioError.invalidVideo }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        self.file = file
        self.asset = asset
        videoTrack = track
        self.duration = duration
        videoRange = range
        presentationSize = rect.size
        hasAudio = !audioTracks.isEmpty
    }

    var defaultFrame: CMTime {
        CMTimeAdd(videoRange.start, CMTimeMultiplyByFloat64(videoRange.duration, multiplier: 0.5))
    }

    func frameTime(at fraction: Double) -> CMTime {
        let end = min(videoRange.end, duration)
        let start = max(.zero, videoRange.start)
        let span = CMTimeSubtract(end, start)
        let tick = min(CMTime(value: 1, timescale: 600), span)
        return min(CMTimeAdd(start, CMTimeMultiplyByFloat64(span, multiplier: fraction)), CMTimeSubtract(end, tick))
    }
}

enum StudioError: LocalizedError {
    case importUnavailable
    case invalidVideo
    case unsupportedCodec
    case multipleVideoTracks
    case noKeyFrame
    case writePhoto
    case writeMovie
    case metadata
    case timelineChanged
    case previewUnavailable(String?)
    case photosPermission
    case saveUnconfirmed

    var errorDescription: String? {
        switch self {
        case .importUnavailable: "De videokiezer heeft geen leesbaar bestand geleverd."
        case .invalidVideo: "Dit bestand bevat geen afspeelbare video met een geldige duur."
        case .unsupportedCodec: "Kies een MP4- of MOV-video met H.264 of HEVC."
        case .multipleVideoTracks: "Dit bestand heeft meerdere actieve videosporen en kan niet als één Live Photo worden omgezet."
        case .noKeyFrame: "Het gekozen hoofdframe kon niet worden gelezen. Kies een ander frame en probeer opnieuw."
        case .writePhoto: "Het hoofdframe kon niet worden opgeslagen."
        case .writeMovie: "De video of audio kon niet in de Live Photo worden opgenomen."
        case .metadata: "De koppeling tussen de foto en video kon niet worden gemaakt."
        case .timelineChanged: "De volledige tijdlijn kon niet behouden blijven. Er is niets opgeslagen."
        case .previewUnavailable(let details):
            "iOS kon geen Live Photo-voorbeeld openen. Je kunt het volledige bestand in Foto’s proberen op te slaan."
                + (details.map { "\n\n\($0)" } ?? "")
        case .photosPermission: "Sta in Instellingen toe dat Live Photo Studio foto’s toevoegt."
        case .saveUnconfirmed: "Foto’s heeft de opslag niet bevestigd."
        }
    }
}
