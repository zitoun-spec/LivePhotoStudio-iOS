import AVFoundation
import Foundation

/// Moves compressed samples into a QuickTime container without decoding or re-encoding them.
/// Writer callbacks and mutable state are confined to a single serial queue.
final class MovieRemuxer: @unchecked Sendable {
    private struct Track {
        let source: AVAssetReaderTrackOutput
        let destination: AVAssetWriterInput
        let range: CMTimeRange
        let timescale: CMTimeScale
        let codec: FourCharCode
        let transform: CGAffineTransform
    }

    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let metadata: AVAssetWriterInputMetadataAdaptor
    private let tracks: [Track]
    private let queue = DispatchQueue(label: "studio.livephoto.remux")
    private var unfinished = Set<Int>()
    private var continuation: CheckedContinuation<Void, Error>?

    init(video: ImportedVideo, outputURL: URL, identifier: String) async throws {
        let reader = try AVAssetReader(asset: video.asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let contentID = AVMutableMetadataItem()
        contentID.identifier = .quickTimeMetadataContentIdentifier
        contentID.dataType = kCMMetadataBaseDataType_UTF8 as String
        contentID.value = identifier as NSString
        writer.metadata = [contentID]

        var tracks: [Track] = []
        let audio = try await video.asset.loadTracks(withMediaType: .audio)
        for track in [video.videoTrack] + audio {
            let range = try await track.load(.timeRange)
            guard !range.isEmpty else { continue }
            guard let format = try await track.load(.formatDescriptions).first else { throw StudioError.writeMovie }

            let source = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            source.alwaysCopiesSampleData = false
            let destination = AVAssetWriterInput(mediaType: track.mediaType, outputSettings: nil, sourceFormatHint: format)
            let transform = try await track.load(.preferredTransform)
            let timescale = try await track.load(.naturalTimeScale)
            if track.mediaType == .video {
                destination.transform = transform
                destination.mediaTimeScale = timescale
            }
            if let language = try await track.load(.extendedLanguageTag) {
                destination.extendedLanguageTag = language
            }
            destination.marksOutputTrackAsEnabled = try await track.load(.isEnabled)
            guard reader.canAdd(source), writer.canAdd(destination) else { throw StudioError.writeMovie }
            reader.add(source)
            writer.add(destination)
            tracks.append(Track(
                source: source, destination: destination, range: range, timescale: timescale,
                codec: CMFormatDescriptionGetMediaSubType(format), transform: transform
            ))
        }

        let spec: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/\(LivePhotoConverter.stillImageKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataBaseDataType_SInt8 as String
        ]
        var metadataFormat: CMMetadataFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [spec] as CFArray,
            formatDescriptionOut: &metadataFormat
        )
        guard status == noErr, let metadataFormat else { throw StudioError.metadata }
        let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metadataFormat)
        guard writer.canAdd(metadataInput) else { throw StudioError.metadata }
        writer.add(metadataInput)
        self.metadata = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)
        self.tracks = tracks
        self.reader = reader
        self.writer = writer
    }

    func write(stillTime: CMTime, duration: CMTime) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.continuation = continuation
                self.begin(stillTime: stillTime, duration: duration)
            }
        }
    }

    private func begin(stillTime: CMTime, duration: CMTime) {
        guard writer.startWriting(), reader.startReading() else {
            fail(writer.error ?? reader.error ?? StudioError.writeMovie)
            return
        }
        writer.startSession(atSourceTime: .zero)
        unfinished = Set(tracks.indices)
        unfinished.insert(tracks.count)
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = LivePhotoConverter.stillImageKey as NSString
        item.dataType = kCMMetadataBaseDataType_SInt8 as String
        item.value = NSNumber(value: Int8(-1))
        let markerDuration = min(CMTime(value: 1, timescale: 600), CMTimeSubtract(duration, stillTime))
        let marker = AVTimedMetadataGroup(items: [item], timeRange: CMTimeRange(start: stillTime, duration: markerDuration))

        metadata.assetWriterInput.requestMediaDataWhenReady(on: queue) { [self] in
            guard unfinished.contains(tracks.count), metadata.assetWriterInput.isReadyForMoreMediaData else { return }
            guard metadata.append(marker) else {
                fail(writer.error ?? StudioError.metadata)
                return
            }
            finishInput(tracks.count, input: metadata.assetWriterInput, at: duration)
        }
        for (index, track) in tracks.enumerated() {
            track.destination.requestMediaDataWhenReady(on: queue) { [self] in
                guard unfinished.contains(index) else { return }
                while track.destination.isReadyForMoreMediaData {
                    guard let sample = track.source.copyNextSampleBuffer() else {
                        if reader.status == .failed || reader.status == .cancelled {
                            fail(reader.error ?? StudioError.writeMovie)
                        } else {
                            finishInput(index, input: track.destination, at: duration)
                        }
                        return
                    }
                    guard track.destination.append(sample) else {
                        fail(writer.error ?? StudioError.writeMovie)
                        return
                    }
                }
            }
        }
    }

    private func finishInput(_ index: Int, input: AVAssetWriterInput, at duration: CMTime) {
        unfinished.remove(index)
        input.markAsFinished()
        guard unfinished.isEmpty else { return }
        writer.endSession(atSourceTime: duration)
        writer.finishWriting {
            self.queue.async {
                guard self.writer.status == .completed else {
                    self.fail(self.writer.error ?? StudioError.writeMovie)
                    return
                }
                let pending = self.continuation
                self.continuation = nil
                pending?.resume()
            }
        }
    }

    private func fail(_ error: Error) {
        reader.cancelReading()
        writer.cancelWriting()
        unfinished.removeAll()
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: error)
    }

    func validate(at url: URL, sourceDuration: CMTime) async throws -> CMTime {
        let movie = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = try await movie.load(.duration)
        let video = try await movie.loadTracks(withMediaType: .video)
        let audio = try await movie.loadTracks(withMediaType: .audio)
        let outputs = video + audio
        guard outputs.count == tracks.count, Self.sameTime(sourceDuration, duration, timescale: writer.movieTimeScale) else {
            throw StudioError.timelineChanged
        }
        for (original, output) in zip(tracks, outputs) {
            let range = try await output.load(.timeRange)
            let format = try await output.load(.formatDescriptions).first
            let transform = try await output.load(.preferredTransform)
            let timescale = min(original.timescale, writer.movieTimeScale)
            guard format.map(CMFormatDescriptionGetMediaSubType) == original.codec,
                  Self.sameTime(range.start, original.range.start, timescale: timescale),
                  Self.sameTime(range.end, original.range.end, timescale: timescale),
                  output.mediaType != .video || transform == original.transform else {
                throw StudioError.timelineChanged
            }
        }
        return duration
    }

    private static func sameTime(_ lhs: CMTime, _ rhs: CMTime, timescale: CMTimeScale) -> Bool {
        guard lhs.isNumeric, rhs.isNumeric else { return false }
        let difference = CMTimeSubtract(lhs, rhs)
        let tick = CMTime(value: 1, timescale: max(1, timescale))
        return difference >= CMTimeMultiply(tick, multiplier: -1) && difference <= tick
    }
}
