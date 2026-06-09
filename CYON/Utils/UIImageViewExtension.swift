//
//  UIImageViewExtension.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//
import UIKit
import Alamofire

let imageCache = NSCache<AnyObject, UIImage>()

extension UIImageView {
    func downloadImage(url: String, completion: ((UIImage?) -> Void)? = nil) {
        guard !url.isEmpty else { return }

        if let cachedImage = imageCache.object(forKey: url as AnyObject) {
            DispatchQueue.main.async { [weak self] in
                self?.image = cachedImage
                completion?(cachedImage)
            }
            return
        }

        AF.request(url).responseData { response in
            guard let data = response.value, let image = UIImage(data: data) else { return }

            imageCache.setObject(image, forKey: url as AnyObject)
            DispatchQueue.main.async { [weak self] in
                guard let imageView = self else { return }
                UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    imageView.image = image
                }, completion: nil)
                completion?(image)
            }
        }
    }
}
