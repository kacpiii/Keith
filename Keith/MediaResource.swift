//
//  MediaResource.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 15/12/16.
//  Copyright © 2016 movile. All rights reserved.
//

import Foundation
import MobileCoreServices

struct MediaResource {
    
    enum `Type` {
        case audio
        case video
        
        var uti: String {
            switch self {
            case .audio:
                return kUTTypeMP3 as String
                
            case .video:
                return kUTTypeMPEG4 as String
            }
        }
    }
    
    enum Source {
        case localFile
        case streaming
    }
    
    let encryptedUrl: URL?
    let type: Type
    let source: Source
    let className: String
    let courseName: String
    let producerName: String
    let artworkUrl: URL?
}

extension MediaResource {
    static let artworkFormatName = "com.movile.vivolearning.cache.artwork"
    
    func getArtwork(completionHandler: @escaping (UIImage?) -> Void) {
//        guard let artworkUrl = artworkUrl else {
//            completionHandler(nil)
//            return
//        }
//        
//        let cache = Shared.imageCache
//        
//        // Limit artwork cache to 10 MB
//        let artworkFormat = Format<UIImage>(name: MediaResource.artworkFormatName, diskCapacity: 10 * 1024 * 1024) { image in
//            return image
//        }
//        
//        cache.addFormat(artworkFormat)
//    
//        cache.fetch(URL: artworkUrl, formatName: MediaResource.artworkFormatName).onSuccess { image in
//            completionHandler(image)
//        }
    }
}



