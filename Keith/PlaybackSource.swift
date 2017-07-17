//
//  PlaybackSource.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import MobileCoreServices
import MediaPlayer

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
    case audio
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

public enum SourceType {
    case url(url: URL)
    case asset(asset: AVAsset)
}

public struct PlaybackSource {
    public let url: URL?
    public let asset: AVAsset?
    public let type: PlaybackType
    
    public init(sourceType: SourceType, type: PlaybackType) {
        switch sourceType {
        case .url(let url):
            self.url = url
            self.asset = AVURLAsset(url: url)
            
        case .asset(let asset):
            self.url = (asset as? AVURLAsset)?.url ?? nil
            self.asset = asset
        }
        
        self.type = type
    }
}
