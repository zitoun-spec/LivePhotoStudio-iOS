import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @StateObject private var model = StudioModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var showSources = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showFrame = false
    @State private var playbackRequest = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = Color(red: 0.78, green: 0.68, blue: 1)
    private let surface = Color(red: 0.092, green: 0.079, blue: 0.133)
    private let edge = Color.white.opacity(0.10)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                previewCard
                if model.video != nil, model.resources == nil {
                    frameCard
                }
                if let resources = model.resources {
                    resultDetails(resources)
                }
                if let activity = model.activity {
                    HStack(spacing: 12) {
                        ProgressView().tint(accent)
                        Text(activity.label)
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: 530)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
                .frame(maxWidth: 530)
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(edge).frame(height: 1) }
        }
        .background {
            ZStack(alignment: .topTrailing) {
                Color(red: 0.050, green: 0.042, blue: 0.075)
                RadialGradient(
                    colors: [Color(red: 0.19, green: 0.11, blue: 0.33), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 390
                )
            }
            .ignoresSafeArea()
        }
        .tint(accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.23), value: model.resources != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.23), value: model.video != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.23), value: showFrame)
        .confirmationDialog("Kies een video", isPresented: $showSources, titleVisibility: .visible) {
            Button("Apple Foto’s") { showPhotos = true }
            Button("Bestanden") { showFiles = true }
            Button("Annuleer", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotos, selection: $photoSelection,
            matching: .videos, preferredItemEncoding: .current
        )
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task {
                await model.importPhotos(item)
                photoSelection = nil
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.quickTimeMovie, .mpeg4Movie, .movie]) { result in
            switch result {
            case .success(let url):
                Task { await model.importFiles(url) }
            case .failure(let error):
                model.error = error.localizedDescription
            }
        }
        .onChange(of: model.video?.file.url) { showFrame = false }
        .alert("Live Photo Studio", isPresented: Binding(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "livephoto")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 50, height: 50)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Live Photo\nStudio")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Van video naar Live Photo, op je iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let livePhoto = model.livePhoto {
                    LivePhotoPreview(photo: livePhoto, playbackRequest: playbackRequest)
                        .accessibilityLabel("Live Photo-voorbeeld")
                } else if model.resources == nil, let player = model.player {
                    VideoPlayer(player: player)
                        .accessibilityLabel("Videovoorbeeld")
                } else {
                    emptyPreview
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background(.black.opacity(0.54))
            .clipped()

            if let video = model.video {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: model.livePhoto == nil ? "film" : "livephoto")
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.file.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text("\(Self.time(video.duration, fractional: true)) · \(video.hasAudio ? "Met audio" : "Zonder audio")")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if model.livePhoto != nil {
                        Button {
                            playbackRequest += 1
                        } label: {
                            Image(systemName: "play.fill")
                                .frame(minWidth: 44, minHeight: 44)
                                .background(accent.opacity(0.13), in: Circle())
                        }
                        .accessibilityLabel("Speel Live Photo af")
                    }
                }
                .padding(15)
            }
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .overlay { RoundedRectangle(cornerRadius: 25).strokeBorder(edge).allowsHitTesting(false) }
    }

    private var aspectRatio: CGFloat {
        guard let size = model.video?.presentationSize else { return 1.25 }
        return min(max(size.width / size.height, 0.95), 2.1)
    }

    private var emptyPreview: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach([64.0, 90, 116], id: \.self) { size in
                    Circle()
                        .strokeBorder(accent.opacity(size == 64 ? 0.55 : 0.18), lineWidth: 1)
                        .frame(width: size, height: size)
                }
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: model.resources == nil ? "play.fill" : "livephoto.slash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)
            Text(model.resources == nil ? "Kies een video om te beginnen" : "Live Photo-voorbeeld niet beschikbaar")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(colors: [accent.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 155)
        }
    }

    private var frameCard: some View {
        DisclosureGroup(isExpanded: $showFrame) {
            VStack(alignment: .leading, spacing: 9) {
                Slider(value: Binding(
                    get: { model.frameFraction ?? 0.5 },
                    set: { model.selectFrame($0) }
                ), in: 0...1)
                .accessibilityLabel("Positie van het hoofdframe")
                .accessibilityValue(Self.time(model.chosenFrame ?? .zero))
                HStack {
                    Text(Self.time(model.chosenFrame ?? .zero, fractional: true))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.frameFraction != nil {
                        Button("Automatisch") { model.resetFrame() }
                            .font(.footnote.weight(.medium))
                    }
                }
            }
            .padding(.top, 9)
        } label: {
            Label("Kies een hoofdframe", systemImage: "viewfinder")
                .font(.subheadline.weight(.semibold))
        }
        .disabled(model.busy)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(edge).allowsHitTesting(false) }
    }

    private func resultDetails(_ resources: LivePhotoResources) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.didSave {
                Label("Live Photo opgeslagen in Foto’s", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.64, green: 0.93, blue: 0.78))
            }
            LabeledContent("Videoduur", value: Self.time(resources.duration, fractional: true))
            LabeledContent("Hoofdframe", value: Self.time(resources.photoTime, fractional: true))
            if let previewError = model.previewError {
                Text(previewError)
            }
            if resources.duration.seconds > 3 {
                Text("De gekoppelde video heeft de volledige duur. Hoeveel Foto’s afspeelt, hangt af van iOS.")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(edge).allowsHitTesting(false) }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if model.resources != nil {
                primary(model.didSave ? "Opgeslagen in Foto’s" : "Save Live Photo",
                        icon: model.didSave ? "checkmark" : "square.and.arrow.down") {
                    Task { await model.save() }
                }
                .disabled(model.busy || model.didSave)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { frameAction; importAction }
                    VStack(spacing: 3) { frameAction; importAction }
                }
            } else if model.video != nil {
                primary("Convert to Live Photo", icon: "livephoto") {
                    Task { await model.convert() }
                }
                .disabled(model.busy)
                importAction
            } else {
                primary("Import Video", icon: "plus") { showSources = true }
                    .disabled(model.busy)
            }
        }
    }

    private var frameAction: some View {
        Button("Hoofdframe wijzigen") {
            showFrame = true
            model.editFrame()
        }
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: 44)
        .disabled(model.busy)
    }

    private var importAction: some View {
        Button("Import Video") { showSources = true }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .disabled(model.busy)
    }

    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color(red: 0.11, green: 0.065, blue: 0.19))
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(colors: [Color(red: 0.86, green: 0.76, blue: 1), accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 17)
                )
                .opacity(model.busy ? 0.58 : 1)
        }
        .buttonStyle(.plain)
    }

    private static func time(_ time: CMTime, fractional: Bool = false) -> String {
        let value = max(0, time.seconds)
        let whole = Int(value.rounded(.down))
        let seconds = whole % 60
        let minutes = (whole / 60) % 60
        let hours = whole / 3600
        let main = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
        return fractional ? main + String(format: ",%02d", Int((value - Double(whole)) * 100)) : main
    }
}

private struct LivePhotoPreview: UIViewRepresentable {
    let photo: PHLivePhoto
    let playbackRequest: Int

    final class Coordinator {
        var lastRequest: Int
        init(lastRequest: Int) { self.lastRequest = lastRequest }
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastRequest: playbackRequest) }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.isMuted = false
        view.livePhoto = photo
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        if view.livePhoto !== photo {
            view.stopPlayback()
            view.livePhoto = photo
        }
        if playbackRequest != context.coordinator.lastRequest {
            context.coordinator.lastRequest = playbackRequest
            view.startPlayback(with: .full)
        }
    }

    static func dismantleUIView(_ view: PHLivePhotoView, coordinator: Coordinator) {
        view.stopPlayback()
        view.livePhoto = nil
    }
}
