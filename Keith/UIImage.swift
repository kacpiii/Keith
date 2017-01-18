//
//  UIImage.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 09/01/17.
//  Copyright © 2017 movile. All rights reserved.
//

import UIKit

internal extension UIImage {
    func draw(at targetSize: CGSize) -> UIImage {
        
        guard !self.size.equalTo(CGSize.zero) else {
            KeithLog("Invalid image size: (0,0)")
            return self
        }
        
        guard !targetSize.equalTo(CGSize.zero) else {
            KeithLog("Invalid target size: (0,0)")
            return self
        }
        
        let scaledSize = sizeThatFills(targetSize)
        let x = (targetSize.width - scaledSize.width) / 2.0
        let y = (targetSize.height - scaledSize.height) / 2.0
        let drawingRect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0)
        draw(in: drawingRect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage!
        
    }
    
    func sizeThatFills(_ other: CGSize) -> CGSize {
        guard !size.equalTo(CGSize.zero) else {
            return other
        }
        let heightRatio = other.height / size.height
        let widthRatio = other.width / size.width
        if heightRatio > widthRatio {
            return CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            return CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
    }
}

