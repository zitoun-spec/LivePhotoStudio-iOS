import Photos
import UIKit

enum PhotoLibrary {
    @MainActor
    static func preview(of resources: LivePhotoResources) async throws -> PHLivePhoto {
        try await withCheckedThrowingContinuation { continuation in
            PHLivePhoto.request(
                withResourceFileURLs: [resources.photoURL, resources.movieURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { photo, info in
                guard (info[PHLivePhotoInfoIsDegradedKey] as? Bool) != true else { return }
                if let photo, (info[PHLivePhotoInfoCancelledKey] as? Bool) != true {
                    continuation.resume(returning: photo)
                } else {
                    continuation.resume(throwing: StudioError.previewUnavailable)
                }
            }
        }
    }

    @MainActor
    static func save(_ resources: LivePhotoResources) async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else { throw StudioError.photosPermission }

        let photo = resources.photoURL
        let movie = resources.movieURL
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: photo, options: nil)
                request.addResource(with: .pairedVideo, fileURL: movie, options: nil)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? StudioError.saveUnconfirmed)
                }
            }
        }
    }
}
