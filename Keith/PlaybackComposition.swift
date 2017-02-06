//
//  PlaybackComposition.swift
//  Keith
//
//  Created by Rafael Alencar on 26/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import AVFoundation

public struct PlaybackComposition {
    
    public let compositedSource: PlaybackSource
    public let mainAsset: AVAsset
    
    init(compositedSource: PlaybackSource, mainAsset: AVAsset) {
        self.compositedSource = compositedSource
        self.mainAsset = mainAsset
    }
    
    public static func overlappingComposition(for assets: [AVAsset], playbackType: PlaybackType) -> PlaybackComposition? {
        
        let mediaType: String
        
        switch playbackType {
        case .audio:
            mediaType = AVMediaTypeAudio
            
        case .video:
            mediaType = AVMediaTypeVideo
        }
        
        guard let mainAsset = assets.first,
            let mainTrack = mainAsset.tracks(withMediaType: mediaType).first else { return nil }
        
        let overlappingComposition = AVMutableComposition()
        let startTime = (0.0).asCMTime
        let timeRange = mainTrack.timeRange
        
        for asset in assets {
            guard let track = asset.tracks(withMediaType: mediaType).first else { continue }
            
            let compositionTrack = overlappingComposition.addMutableTrack(withMediaType: mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)
         
            do {
                try compositionTrack.insertTimeRange(timeRange, of: track, at: startTime)
            }
            catch {
                return nil
            }
        }
        
        let source = PlaybackSource(asset: overlappingComposition, type: playbackType)
        let composition = PlaybackComposition(compositedSource: source, mainAsset: mainAsset)
        
        return composition
    }
}
