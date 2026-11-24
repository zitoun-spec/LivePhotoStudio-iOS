import Photos
import UIKit

enum PhotoLibrary {
    @MainActor
    static func preview(of resources: LivePhotoResources) async throws -> PHLivePhoto {
        try await withCheckedThrowingContinuation { continuation in
            var pending: CheckedContinuation<PHLivePhoto, Error>? = continuation
            PHLivePhoto.request(
                withResourceFileURLs: [resources.photoURL, resources.movieURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { photo, info in
                let cancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) == true
                let error = info[PHLivePhotoInfoErrorKey] as? Error
                let degraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) == true
                guard !degraded || cancelled || error != nil, let completion = pending else { return }
                pending = nil
                if let photo, !cancelled, error == nil {
                    completion.resume(returning: photo)
                } else {
                    completion.resume(throwing: StudioError.previewUnavailable(error?.localizedDescription))
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
