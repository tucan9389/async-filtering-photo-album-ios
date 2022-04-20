//
//  AssetManager.swift
//  FilteringPhotoAlbum_Example
//
//  Created by Doyoung Gwak on 2022/04/19.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Photos
import UIKit

protocol PhotoAssetManagerDelegate {
    func process(for image: UIImage) -> String
    func update(at index: Int, for count: Int)
}

class PhotoAssetManager: NSObject {
    private let imageManager = PHCachingImageManager()
    private var cameraRollFetchResult: PHFetchResult<PHAssetCollection>?
    private var assetsFetchResult: PHFetchResult<PHAsset>?
    public var assets: [PHAsset] = []
    public var idToCategoryName: [String: String] = [:]
    public var categoryNameToAssets: [String: [PHAsset]] = [:]
    public var delegate: PhotoAssetManagerDelegate?
    
    private var assetFetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    private var thumbnailImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        return options
    }()
    
    private var imageDataRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        return options
    }()
    
    private let size: CGFloat = 66
    private var thumbNailTargetSize: CGSize {
        let width = 224// * UIScreen.main.scale
        return CGSize(width: width, height: width)
    }
    
    public func fetchAlbum() {
        cameraRollFetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        guard let cameraRollCollection = cameraRollFetchResult?.firstObject else { fatalError() }
        
        let assetsFetchResult = PHAsset.fetchAssets(in: cameraRollCollection, options: assetFetchOptions)
        self.assetsFetchResult = assetsFetchResult
        guard let count = self.assetsFetchResult?.count else { fatalError() }
        
        DispatchQueue(label: "com.tucan9389.inference").async { [weak self] in
            guard let self = self else { return }
            self.assetsFetchResult?.enumerateObjects { asset, index, _ in
                self.requestImage(for: asset) { image, info in
                    // inference
                    guard let image = image else { fatalError() }
                    if 224 > min(image.size.height, image.size.width) { return }
                    guard let result = self.delegate?.process(for: image) else { fatalError() }
                    
                    // set the result
                    self.idToCategoryName[asset.localIdentifier] = result
                    self.categoryNameToAssets[result]?.append(asset)
                    self.assets.append(asset)
                    
                    // callback update
                    self.delegate?.update(at: index, for: count)
                }
            }
        }
    }
}

extension PhotoAssetManager: PHPhotoLibraryChangeObserver {
    
    public func registerObserver() {
        PHPhotoLibrary.shared().register(self)
    }
    
    public func unregisterObserver() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    @discardableResult
    public func requestImage(for asset: PHAsset, targetSize: CGSize? = nil, options: PHImageRequestOptions? = nil, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let requestID = imageManager.requestImage(for: asset, targetSize: targetSize ?? thumbNailTargetSize, contentMode: .aspectFill, options: options ?? thumbnailImageRequestOptions) { (image, info) in
            completion(image, info)
        }
        
        return requestID
    }
    
    @discardableResult
    public func requestImageData(for asset: PHAsset, targetSize: CGSize? = nil, options: PHImageRequestOptions? = nil, completion: @escaping (Data?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let requestID = imageManager.requestImageData(for: asset, options: options ?? imageDataRequestOptions) { (data, _, _, info) in
            completion(data, info)
        }
        
        return requestID
    }

    public func cancelImageRequest(for requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
    
    public func startCaching(for assets: [PHAsset], size: CGSize? = nil, options: PHImageRequestOptions? = nil) {
        imageManager.startCachingImages(for: assets, targetSize: size ?? thumbNailTargetSize, contentMode: .aspectFill, options: options ?? thumbnailImageRequestOptions)
    }
    
    public func stopCaching(for assets: [PHAsset], size: CGSize? = nil, options: PHImageRequestOptions? = nil) {
        imageManager.stopCachingImages(for: assets, targetSize: size ?? thumbNailTargetSize, contentMode: .aspectFill, options: options ?? thumbnailImageRequestOptions)
    }
    
    public func stopCachingAllAssets() {
        imageManager.stopCachingImagesForAllAssets()
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        /*if let assetsBeforeChanges = assets {
            synchronizeAssets(fetchRequestBeforeChanges: assetsBeforeChanges, changeInstance: changeInstance)
        }*/
        print("album is changed, but not implemented!")
    }
}
