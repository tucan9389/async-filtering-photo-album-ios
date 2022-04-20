//
//  AlbumCollectionViewController.swift
//  FilteringPhotoAlbum_Example
//
//  Created by Doyoung Gwak on 2022/04/19.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import UIKit
import Vision



class AlbumCollectionViewController: UIViewController {
    
    let classifier = Classifier()
    
    @IBOutlet weak var segmentControl: UISegmentedControl?
    @IBOutlet weak var collectionView: UICollectionView?
    
    lazy var columnLayout: ColumnFlowLayout = {
        return ColumnFlowLayout(
            cellsPerRow: 5, /// CHANGE HERE
            minimumInteritemSpacing: 4,
            minimumLineSpacing: 4,
            sectionInset: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        )
    }()
    
    let assetManager = PhotoAssetManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ---------------------------------------------------
        // set up asset manager
        // ---------------------------------------------------
        
        assetManager.delegate = self
        assetManager.fetchAlbum()
        
        // ---------------------------------------------------
        // set up mlmodel
        // ---------------------------------------------------
        
        segmentControl?.isEnabled = false
        segmentControl?.addTarget(self, action: #selector(segmentControlChanged(_:)), for: .valueChanged)
        print(classifier.categoryNames.count)
        for (i, title) in classifier.categoryNames[...4].enumerated() {
            self.segmentControl?.insertSegment(withTitle: title, at: i, animated: false)
        }
        self.segmentControl?.selectedSegmentIndex = 0
        self.segmentControl?.isEnabled = true
        
        // ---------------------------------------------------
        // set up collection view
        // ---------------------------------------------------
        
        collectionView?.delegate = self
        collectionView?.dataSource = self
        
        collectionView?.collectionViewLayout = columnLayout
        
        collectionView?.contentInsetAdjustmentBehavior = .always
        //collectionView?.register(ImageCollectionViewCell.self, forCellWithReuseIdentifier: "ImageCollectionViewCell")
        collectionView?.register(UINib(nibName: ImageCollectionViewCell.reuseIdentifier, bundle: .main), forCellWithReuseIdentifier: ImageCollectionViewCell.reuseIdentifier)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getSelectedName() -> String {
        guard let selectedIndex = segmentControl?.selectedSegmentIndex else { fatalError() }
        guard let targetCategoryName = segmentControl?.titleForSegment(at: selectedIndex) else { fatalError() }
        return targetCategoryName
    }
    
    @objc func segmentControlChanged(_ sender: AnyObject) {
        
    }
    
}

extension AlbumCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // print(assetManager.assets.count)
        // return assetManager.assets.count
        let targetCategoryName = getSelectedName()
        if assetManager.categoryNameToAssets.keys.contains(targetCategoryName) {
            return assetManager.categoryNameToAssets[targetCategoryName]?.count ?? 0
        } else {
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCollectionViewCell.reuseIdentifier, for: indexPath)
        // cell.backgroundColor = UIColor.orange
        
        let targetCategoryName = getSelectedName()
        // let asset = assetManager.assets/*assetManager.categoryNameToAssets[targetCategoryName]?*/[indexPath.row]
        if let asset = assetManager.categoryNameToAssets[targetCategoryName]?[indexPath.row] {
        (cell as? ImageCollectionViewCell)?.localIdentifier = asset.localIdentifier
            assetManager.requestImage(for: asset) { image, _ in
                if (cell as? ImageCollectionViewCell)?.localIdentifier == asset.localIdentifier {
                    (cell as? ImageCollectionViewCell)?.imageView?.image = image
                }
            }
        }
        
            
        
        return cell
    }
}

extension AlbumCollectionViewController: UICollectionViewDelegate { }

extension AlbumCollectionViewController: PhotoAssetManagerDelegate {
    func process(for image: UIImage) -> String {
        return classifier.inference(image)
    }
    
    func update(at index: Int, for count: Int) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
}

// https://stackoverflow.com/a/41409642/4160632
class ColumnFlowLayout: UICollectionViewFlowLayout {

    let cellsPerRow: Int

    init(cellsPerRow: Int, minimumInteritemSpacing: CGFloat = 0, minimumLineSpacing: CGFloat = 0, sectionInset: UIEdgeInsets = .zero) {
        self.cellsPerRow = cellsPerRow
        super.init()

        self.minimumInteritemSpacing = minimumInteritemSpacing
        self.minimumLineSpacing = minimumLineSpacing
        self.sectionInset = sectionInset
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else { return }
        let marginsAndInsets = sectionInset.left + sectionInset.right + collectionView.safeAreaInsets.left + collectionView.safeAreaInsets.right + minimumInteritemSpacing * CGFloat(cellsPerRow - 1)
        let itemWidth = ((collectionView.bounds.size.width - marginsAndInsets) / CGFloat(cellsPerRow)).rounded(.down)
        itemSize = CGSize(width: itemWidth, height: itemWidth)
    }

    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds) as! UICollectionViewFlowLayoutInvalidationContext
        context.invalidateFlowLayoutDelegateMetrics = newBounds.size != collectionView?.bounds.size
        return context
    }
}

extension UIImage {
    static func imageWithPixelSize(size: CGSize, filledWithColor color: UIColor = UIColor.clear, opaque: Bool = false) -> UIImage? {
        return imageWithSize(size: size, filledWithColor: color, scale: 1.0, opaque: opaque)
    }

    static func imageWithSize(size: CGSize, filledWithColor color: UIColor = UIColor.clear, scale: CGFloat = 0.0, opaque: Bool = false) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        color.set()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

// https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2.mlmodel

class Classifier {
    
    var categoryNames: [String] = []
    private lazy var model: VNCoreMLModel = {
        // Use a default model configuration.
        let defaultConfig = MLModelConfiguration()

        // Create an instance of the image classifier's wrapper class.
        let imageClassifierWrapper = try? MobileNetV2(configuration: defaultConfig)

        guard let imageClassifier = imageClassifierWrapper else {
            fatalError("App failed to create an image classifier model instance.")
        }
        
        guard let image = UIImage.imageWithPixelSize(size: CGSize(width: 224, height: 224)) else { fatalError() }
        if let result = try? imageClassifier.prediction(image: image.pixelBufferFromImage()) {
            categoryNames = result.classLabelProbs.keys.map { String($0) }
        }

        // Get the underlying model instance.
        let imageClassifierModel = imageClassifier.model

        // Create a Vision instance using the image classifier's model instance.
        guard let imageClassifierVisionModel = try? VNCoreMLModel(for: imageClassifierModel) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }
        
        

        return imageClassifierVisionModel
    }()
    
    var imageClassificationRequest: VNCoreMLRequest?
    var result: String?
    
    init() {
        imageClassificationRequest = VNCoreMLRequest(model: model) { [weak self] request, _ in
            guard let self = self else { return }
            guard let observation = request.results?.first as? VNClassificationObservation else { return }
            self.result = observation.identifier
        }
        imageClassificationRequest?.imageCropAndScaleOption = .centerCrop
    }
    
    func inference(_ image: UIImage) -> String {
        result = nil
        guard let imageClassificationRequest = imageClassificationRequest else { fatalError() }
        let handler = VNImageRequestHandler(cvPixelBuffer: image.pixelBufferFromImage())
        try? handler.perform([imageClassificationRequest])
        guard let result = result else { fatalError() }
        return result
    }
}

class ImageCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "ImageCollectionViewCell"
    var localIdentifier: String?
    @IBOutlet weak var imageView: UIImageView?
}
