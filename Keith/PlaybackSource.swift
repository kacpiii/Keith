//
//  PlaybackSource.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import MobileCoreServices
import AVFoundation

public struct NowPlayingInfo {
    public let title: String
    public let albumTitle: String
    public let artist: String
    public let artworkUrl: URL?
    
    public init(title: String, albumTitle: String, artist: String, artworkUrl: URL?) {
        self.title = title
        self.albumTitle = albumTitle
        self.artist = artist
        self.artworkUrl = artworkUrl
    }
}

public enum PlaybackType {
    case audio(nowPlayingInfo: NowPlayingInfo?)
    case video
    
    public var uti: String {
        switch self {
        case .audio:
            return kUTTypeMP3 as String
            
        case .video:
            return kUTTypeMPEG4 as String
        }
    }
}

public struct PlaybackSource {
    
    public let asset: AVAsset
    public let playerItem: AVPlayerItem
    public let type: PlaybackType
    
    public init(asset: AVAsset, type: PlaybackType) {
        self.asset = asset
        self.playerItem = AVPlayerItem(asset: asset)
        self.type = type
    }
    
    public init(url: URL, type: PlaybackType) {
        let asset = AVURLAsset(url: url)
        self.init(asset: asset, type: type)
    }
    
    public init?(url: URL, type: PlaybackType, resourceLoaderDelegate: AVAssetResourceLoaderDelegate? = nil, queue: DispatchQueue? = nil) {
        
        let assetUrl: URL? = {
            if resourceLoaderDelegate != nil {
                return url.convertToRedirectURL()
            }
            
            return url
        }()
        
        guard let _assetUrl = assetUrl else { return nil }
        
        let asset = AVURLAsset(url: _assetUrl)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: queue)
        
        self.init(asset: asset, type: type)
    }
}
