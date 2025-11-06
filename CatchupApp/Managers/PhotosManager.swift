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
    
    // Find Photos person collection by contact name
    // Note: Photos People collections (face recognition) are not directly accessible via API
    // So we search through user albums and smart albums for matching names
    func findPersonCollection(for contactName: String) -> String? {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return nil
        }
        
        // Normalize contact name for matching
        let normalizedContactName = contactName.lowercased().trimmingCharacters(in: .whitespaces)
        let nameComponents = normalizedContactName.components(separatedBy: .whitespaces)
        
        // Search through user-created albums
        let userAlbums = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        var foundCollection: PHAssetCollection?
        
        userAlbums.enumerateObjects { (collection: PHCollection, _, stop) in
            if let assetCollection = collection as? PHAssetCollection {
                let collectionName = assetCollection.localizedTitle?.lowercased() ?? ""
                
                // Check exact match
                if collectionName == normalizedContactName {
                    foundCollection = assetCollection
                    stop.pointee = true
                    return
                }
                
                // Check if any name component matches (e.g., "John" matches "John Doe")
                for component in nameComponents {
                    if !component.isEmpty && collectionName.contains(component) {
                        foundCollection = assetCollection
                        stop.pointee = true
                        return
                    }
                }
            }
        }
        
        // Also search smart albums (some users might organize photos this way)
        if foundCollection == nil {
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            
            smartAlbums.enumerateObjects { collection, _, stop in
                let collectionName = collection.localizedTitle?.lowercased() ?? ""
                
                // Check exact match
                if collectionName == normalizedContactName {
                    foundCollection = collection
                    stop.pointee = true
                    return
                }
                
                // Check if any name component matches
                for component in nameComponents {
                    if !component.isEmpty && collectionName.contains(component) {
                        foundCollection = collection
                        stop.pointee = true
                        return
                    }
                }
            }
        }
        
        return foundCollection?.localIdentifier
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
        
        // Fetch user-created albums (people might organize photos this way)
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
        
        // Also include smart albums
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        smartAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            if assets.count > 0 {
                collections.append((
                    name: collection.localizedTitle ?? "Unnamed",
                    identifier: collection.localIdentifier,
                    count: assets.count
                ))
            }
        }
        
        return collections.sorted { $0.name < $1.name }
    }
}

