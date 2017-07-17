//
//  PlaybackConfiguration.swift
//  Keith
//
//  Created by Rafael Alencar on 25/04/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import AVFoundation

public struct PlaybackConfiguration {
    public var playWhenReady: Bool
    public var startTime: TimeInterval
    public var resourceLoaderDelegate: AVAssetResourceLoaderDelegate?
    public var automaticallyWaitsToMinimizeStalling: Bool
}

extension PlaybackConfiguration {
    public static let `default`: PlaybackConfiguration = {
        let playWhenReady = false
        let startTime: TimeInterval = 0.0
        let automaticallyWaitsToMinimizeStalling = true
        
        return PlaybackConfiguration(playWhenReady: playWhenReady, startTime: startTime, resourceLoaderDelegate: nil, automaticallyWaitsToMinimizeStalling: automaticallyWaitsToMinimizeStalling)
    }()
}
