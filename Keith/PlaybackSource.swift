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
    case audio(nowPlayingInfo: NowPlayingInfo)
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
    
    public let url: URL
    public let type: PlaybackType
    
    public init(url: URL, type: PlaybackType) {
        self.url = url
        self.type = type
    }
}
