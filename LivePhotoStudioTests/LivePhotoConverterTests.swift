import AVFoundation
import CryptoKit
import ImageIO
import XCTest
@testable import LivePhotoStudio

final class LivePhotoConverterTests: XCTestCase {
    func testShortMP4WithDefaultFrame() async throws {
        try await check("short-h264", "mp4", duration: 2.5, audio: false)
    }

    func testTwelveSecondMP4KeepsAudio() async throws {
        try await check("audio-h264", "mp4", duration: 12, audio: true, frame: 0.86)
    }

    func testHEVCMOVBeyondThirtySecondsKeepsAudio() async throws {
        try await check("audio-hevc", "mov", duration: 35.5, audio: true, frame: 0.92)
    }

    func testPortraitMOVBeyondOneMinuteKeepsOrientation() async throws {
        try await check("portrait-h264", "mov", duration: 65, audio: false, frame: 0.98, portrait: true)
    }

    private func check(
        _ name: String, _ ext: String, duration expectedDuration: Double, audio expectsAudio: Bool,
        frame fraction: Double? = nil, portrait: Bool = false
    ) async throws {
        #if SWIFT_PACKAGE
        let fixtureBundle = Bundle.module
        #else
        let fixtureBundle = Bundle(for: Self.self)
        #endif
        let fixture = try XCTUnwrap(fixtureBundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
        let file = try ImportedFile.copy(from: fixture)
        defer { file.directory.remove() }
        let video = try await ImportedVideo(file: file)
        XCTAssertEqual(video.duration.seconds, expectedDuration, accuracy: 0.002)
        let frame = fraction.map { video.frameTime(at: $0) } ?? video.defaultFrame
        let result = try await LivePhotoConverter.convert(video, at: frame)
        defer { result.directory.remove() }

        let movie = AVURLAsset(url: result.movieURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = try await movie.load(.duration)
        XCTAssertEqual(duration.seconds, expectedDuration, accuracy: 0.002)
        XCTAssertEqual(result.photoTime.seconds, frame.seconds, accuracy: 1.0 / 12.0 + 0.002)
        let metadata = try await movie.loadMetadata(for: .quickTimeMetadata)
        let content = try XCTUnwrap(metadata.first { $0.identifier == .quickTimeMetadataContentIdentifier })
        let movieIdentifier = try await content.load(.stringValue)

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(result.photoURL as CFURL, nil))
        let attributes = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let maker = try XCTUnwrap(attributes[kCGImagePropertyMakerAppleDictionary] as? [String: Any])
        XCTAssertEqual(maker[LivePhotoConverter.makerIdentifierKey] as? String, result.identifier)
        XCTAssertEqual(movieIdentifier, result.identifier)
        let width = try XCTUnwrap(attributes[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(attributes[kCGImagePropertyPixelHeight] as? Int)
        XCTAssertEqual(portrait ? height : width, 112)
        XCTAssertEqual(portrait ? width : height, 64)

        let inputVideo = try await trackDigest(in: video.asset, mediaType: .video)
        let outputVideo = try await trackDigest(in: movie, mediaType: .video)
        XCTAssertGreaterThan(try XCTUnwrap(inputVideo).count, 0)
        XCTAssertEqual(inputVideo, outputVideo)
        let inputAudio = try await trackDigest(in: video.asset, mediaType: .audio)
        let outputAudio = try await trackDigest(in: movie, mediaType: .audio)
        XCTAssertEqual(outputAudio != nil, expectsAudio)
        XCTAssertEqual(inputAudio, outputAudio)
        try await verifyStillImageTime(in: movie, expected: result.photoTime)
    }

    private func verifyStillImageTime(in movie: AVAsset, expected: CMTime) async throws {
        let marker = try await LivePhotoConverter.readStillImageMarker(in: movie)
        XCTAssertEqual(marker.items.count, 1)
        let item = try XCTUnwrap(marker.items.first)
        XCTAssertEqual(item.key as? String, LivePhotoConverter.stillImageKey)
        XCTAssertEqual(item.dataType, kCMMetadataBaseDataType_SInt8 as String)
        let value = try await item.load(.numberValue)
        XCTAssertEqual(value?.intValue, -1)
        XCTAssertEqual(marker.timeRange.start.seconds, expected.seconds, accuracy: 0.002)
    }

    private struct Digest: Equatable {
        let count: Int
        let data: SHA256.Digest
    }

    private func trackDigest(in asset: AVAsset, mediaType: AVMediaType) async throws -> Digest? {
        let tracks = try await asset.loadTracks(withMediaType: mediaType)
        guard let track = tracks.first else { return nil }
        XCTAssertEqual(tracks.count, 1)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        XCTAssertTrue(reader.startReading(), reader.error?.localizedDescription ?? "Media reader")
        var hasher = SHA256()
        var sampleCount = 0
        while let sample = output.copyNextSampleBuffer() {
            sampleCount += CMSampleBufferGetNumSamples(sample)
            let buffer = try XCTUnwrap(CMSampleBufferGetDataBuffer(sample))
            let count = CMBlockBufferGetDataLength(buffer)
            var data = Data(count: count)
            let status = data.withUnsafeMutableBytes { bytes in
                guard let destination = bytes.baseAddress else { return OSStatus(0) }
                return CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: count, destination: destination)
            }
            XCTAssertEqual(status, noErr)
            hasher.update(data: data)
        }
        XCTAssertEqual(reader.status, .completed, reader.error?.localizedDescription ?? "Media reader")
        return Digest(count: sampleCount, data: hasher.finalize())
    }
}
