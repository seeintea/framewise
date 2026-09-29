import Observation
import Photos
import UIKit

/// Shares small previews across camera pages and saves that outlive those pages.
@MainActor
@Observable
final class CameraAlbumThumbnail: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = CameraAlbumThumbnail()

    nonisolated struct Capture: Sendable {
        let id = UUID()
        let date = Date()
    }

    private struct Preview {
        let image: UIImage
        let date: Date
    }

    private(set) var image: UIImage?
    @ObservationIgnored private var pending: [UUID: Preview] = [:]
    @ObservationIgnored private var saved: (id: UUID, preview: Preview)?
    @ObservationIgnored private var libraryPreview: Preview?
    @ObservationIgnored private var libraryAssetID: String?
    // Keep the fetch alive so PhotoKit can report changes to this library query.
    @ObservationIgnored private var assets: PHFetchResult<PHAsset>?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var requestID: PHImageRequestID?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let imageManager = PHImageManager()

    private override init() { super.init() }

    func start() {
        isActive = true
        refresh()
    }

    func stop() {
        isActive = false
        cancelRequest()
        stopObserving()
        assets = nil
    }

    func showProcessed(_ image: UIImage, for capture: Capture) {
        pending[capture.id] = Preview(image: image, date: capture.date)
        updateImage()
    }

    func finish(_ capture: Capture, succeeded: Bool) {
        if let preview = pending.removeValue(forKey: capture.id), succeeded,
            preview.date > (saved?.preview.date ?? .distantPast)
        {
            saved = (capture.id, preview)
        }
        updateImage()
        if isActive { refresh() }
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self, self.isActive else { return }
            self.refresh()
        }
    }

    private func refresh() {
        cancelRequest()
        // Querying assets without this check can itself trigger an authorization prompt.
        guard PhotoLibraryPermission.isAuthorized(for: .readWrite) else {
            stopObserving()
            libraryPreview = nil
            libraryAssetID = nil
            assets = nil
            updateImage()
            return
        }
        if !isObserving {
            PHPhotoLibrary.shared().register(self)
            isObserving = true
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        assets = result
        guard let asset = result.firstObject else {
            libraryPreview = nil
            libraryAssetID = nil
            saved = nil
            updateImage()
            return
        }
        if libraryAssetID != asset.localIdentifier {
            libraryPreview = nil
            libraryAssetID = asset.localIdentifier
            updateImage()
        }

        let currentGeneration = generation
        let savedID = saved?.id
        let date = asset.creationDate ?? .distantPast
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        requestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActive, self.generation == currentGeneration else { return }
                guard PhotoLibraryPermission.isAuthorized(for: .readWrite) else {
                    self.refresh()
                    return
                }
                guard let image else { return }
                self.libraryPreview = Preview(image: image, date: date)
                // A fresh library result replaces only the save known when this request began.
                if self.saved?.id == savedID { self.saved = nil }
                self.updateImage()
            }
        }
    }

    private func updateImage() {
        var previews = Array(pending.values)
        if let saved { previews.append(saved.preview) }
        if let libraryPreview { previews.append(libraryPreview) }
        image = previews.max { $0.date < $1.date }?.image
    }

    private func cancelRequest() {
        generation = UUID()
        if let requestID { imageManager.cancelImageRequest(requestID) }
        requestID = nil
    }

    private func stopObserving() {
        guard isObserving else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isObserving = false
    }
}
