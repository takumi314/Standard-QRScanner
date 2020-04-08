//
//  UIImage+Crop.swift
//  StandardQRScanner
//
//  Created by NishiokaKohei on 02/04/2020.
//  Copyright © 2020 Takumi. All rights reserved.
//

import UIKit

extension UIImage {

    func crop(_ path: UIBezierPath) -> UIImage? {
        let rect = CGRect(origin: CGPoint(), size: size.scaling(by: scale))

        // 編集開始
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)

        UIColor.clear.setFill()
        UIRectFill(rect)
        path.addClip()
        draw(in: rect)
        // 現在のImageを取得
        let currentImage = UIGraphicsGetImageFromCurrentImageContext()
        // 編集終了
        UIGraphicsEndImageContext()

        // The CGImage cropped only to QRCode area
        let croppingRect
            = CGRect(origin: path.bounds.origin.scaling(by: scale), size: path.bounds.size.scaling(by: scale))
        guard let cgImageCropped = currentImage?.cgImage?.cropping(to: croppingRect) else { return nil }

        return UIImage(cgImage: cgImageCropped, scale: scale, orientation: imageOrientation)
    }

}

private extension CGPoint {
    func scaling(by scale: CGFloat) -> CGPoint {
        CGPoint(x: x*scale, y: y*scale)
    }
}

private extension CGSize {
    func scaling(by scale: CGFloat) -> CGSize {
        CGSize(width: width*scale, height: height*scale)
    }
}
