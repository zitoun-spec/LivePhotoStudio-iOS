import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LivePhotoResources {
    let directory: WorkingDirectory
    let photoURL: URL
    let movieURL: URL
    let identifier: String
    let photoTime: CMTime
    let duration: CMTime
}

enum LivePhotoConverter {
    static let stillImageKey = "com.apple.quicktime.still-image-time"
    static let makerIdentifierKey = "17"

    static func convert(_ video: ImportedVideo, at requestedTime: CMTime) async throws -> LivePhotoResources {
        let directory = try WorkingDirectory()
        do {
            let generator = AVAssetImageGenerator(asset: video.asset)
            generator.appliesPreferredTrackTransform = true
            generator.apertureMode = .cleanAperture
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let frame: (image: CGImage, actualTime: CMTime)
            do {
                frame = try await generator.image(at: requestedTime)
            } catch {
                try Task.checkCancellation()
                generator.requestedTimeToleranceBefore = .positiveInfinity
                generator.requestedTimeToleranceAfter = .positiveInfinity
                frame = try await generator.image(at: requestedTime)
            }
            guard frame.actualTime.isNumeric, frame.actualTime >= .zero, frame.actualTime < video.duration else {
                throw StudioError.noKeyFrame
            }

            let identifier = UUID().uuidString
            let photoURL = directory.url.appending(path: "photo.jpg")
            let movieURL = directory.url.appending(path: "motion.mov")
            try writePhoto(frame.image, to: photoURL, identifier: identifier)

            let remuxer = try await MovieRemuxer(video: video, outputURL: movieURL, identifier: identifier)
            try await remuxer.write(stillTime: frame.actualTime, duration: video.duration)
            let duration = try await remuxer.validate(at: movieURL, sourceDuration: video.duration)
            let marker = try await readStillImageMarker(in: AVURLAsset(url: movieURL))
            guard abs(CMTimeSubtract(marker.timeRange.start, frame.actualTime).seconds) <= 1.0 / 600.0 else {
                throw StudioError.metadata
            }

            return LivePhotoResources(
                directory: directory, photoURL: photoURL, movieURL: movieURL,
                identifier: identifier, photoTime: frame.actualTime, duration: duration
            )
        } catch {
            directory.remove()
            throw error
        }
    }

    static func readStillImageMarker(in movie: AVAsset) async throws -> AVTimedMetadataGroup {
        let tracks = try await movie.loadTracks(withMediaType: .metadata)
        guard tracks.count == 1, let track = tracks.first else { throw StudioError.metadata }
        let reader = try AVAssetReader(asset: movie)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else { throw StudioError.metadata }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? StudioError.metadata }
        defer { reader.cancelReading() }

        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(sample) > 0,
                  let group = AVTimedMetadataGroup(sampleBuffer: sample),
                  group.items.contains(where: { $0.key as? String == stillImageKey }) else { continue }
            return group
        }
        throw reader.error ?? StudioError.metadata
    }

    private static func writePhoto(_ image: CGImage, to url: URL, identifier: String) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw StudioError.writePhoto
        }
        let settings: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0,
            kCGImagePropertyOrientation: 1,
            kCGImagePropertyMakerAppleDictionary: [makerIdentifierKey: identifier]
        ]
        CGImageDestinationAddImage(destination, image, settings as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StudioError.writePhoto }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let maker = properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any],
              maker[makerIdentifierKey] as? String == identifier else {
            throw StudioError.metadata
        }
    }
}
