import Foundation
import Photos
import UIKit
import Combine

class PhotosManager: ObservableObject {
    static let shared = PhotosManager()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    func fetchPhotosForPerson(localIdentifier: String, limit: Int = 10) -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        
        // Try to fetch the person/collection
        if let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        ).firstObject {
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var photos: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                if asset.mediaType == .image {
                    photos.append(asset)
                }
            }
            return photos
        }
        
        return []
    }
    
    func loadImage(from asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let imageManager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    func fetchAllPeopleCollections() -> [(name: String, identifier: String, count: Int)] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }
        
        var collections: [(name: String, identifier: String, count: Int)] = []
        
        // Fetch all user-created albums (people might organize photos this way)
        let userAlbums = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        userAlbums.enumerateObjects { (collection: PHCollection, _: Int, _: UnsafeMutablePointer<ObjCBool>) in
            if let assetCollection = collection as? PHAssetCollection {
                let assets = PHAsset.fetchAssets(in: assetCollection, options: nil)
                if assets.count > 0 {
                    collections.append((
                        name: assetCollection.localizedTitle ?? "Unnamed",
                        identifier: assetCollection.localIdentifier,
                        count: assets.count
                    ))
                }
            }
        }
        
        return collections.sorted { $0.name < $1.name }
    }
}

