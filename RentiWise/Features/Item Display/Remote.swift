// UIImageView+Remote.swift
// RentiWise

import UIKit

private final class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()
}

extension UIImageView {
    // Convenience method for simple use-cases
    static func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = ImageCache.shared.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            var image: UIImage? = nil
            if let data = data {
                image = UIImage(data: data)
                if let img = image {
                    ImageCache.shared.setObject(img, forKey: url as NSURL)
                }
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
}
