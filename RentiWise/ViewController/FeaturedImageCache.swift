//
//  FeaturedImageCache.swift
//  RentiWise
//
//  Created by admin99 on 30/12/25.
//

import UIKit

/// Lightweight shared image cache used across Home, Search, etc.
final class FeaturedImageCache {
    static let shared = FeaturedImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Optional: tune limits if desired
        cache.countLimit = 200   // max number of images
        cache.totalCostLimit = 50 * 1024 * 1024 // ~50 MB
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
