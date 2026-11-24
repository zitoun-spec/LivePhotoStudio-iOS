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

            return LivePhotoResources(
                directory: directory, photoURL: photoURL, movieURL: movieURL,
                identifier: identifier, photoTime: frame.actualTime, duration: duration
            )
        } catch {
            directory.remove()
            throw error
        }
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
