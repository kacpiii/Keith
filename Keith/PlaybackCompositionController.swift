//
//  PlaybackCompositionController.swift
//  Keith
//
//  Created by Rafael Alencar on 06/02/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import AVFoundation

public class PlaybackCompositionController: PlaybackController {
    
    public static let sharedComposition = PlaybackCompositionController()
    
    fileprivate var mainAssetPlayerItem: AVPlayerItem?
    fileprivate var compositedAssetPlayerItem: AVPlayerItem?
    
    fileprivate let mainAssetPlayerItemKeyPaths = ["duration"]
    fileprivate let compositedAssetPlayerItemKeyPaths = ["status"]
    
    private var mainAssetPlayerItemObserver: NSObjectProtocol?
    private var compositedAssetPlayerItemObserver: NSObjectProtocol?
    
    public func prepareToPlay(
        _ playbackComposition: PlaybackComposition,
        configuration: PlaybackConfiguration) {
        
        self.compositedAssetPlayerItem = playbackComposition.compositedSource.playerItem
        
        super.prepareToPlay(
            playbackComposition.compositedSource,
            configuration: configuration
        )
        
        playbackComposition.mainAsset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let this = self else { return }
                
                let asset = playbackComposition.mainAsset
                
                var error: NSError?
                let keyStatus = asset.statusOfValue(forKey: "duration", error: &error)
                
                if keyStatus == .failed {
                    KeithLog("Error when obtaining `duration` key for resource: \(error?.localizedDescription)")
                    
                    return
                }
                
                if asset.duration.isNumeric {
                    this.duration = TimeInterval(CMTimeGetSeconds(asset.duration))
                    
                } else {
                    this.duration = nil
                }
            }
        }
    }
    
    internal override func didSetPlayerItem(oldValue: AVPlayerItem?) {
        oldValue?.remove(observer: self, for: compositedAssetPlayerItemKeyPaths, context: &PlaybackCompositionControllerContext)
        compositedAssetPlayerItem?.add(observer: self, for: compositedAssetPlayerItemKeyPaths, context: &PlaybackCompositionControllerContext)
        compositedAssetPlayerItem?.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain
        
        if let observer = mainAssetPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let item = mainAssetPlayerItem {
            mainAssetPlayerItemObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main,
                using: { [weak self] (note) in
                    guard let this = self else { return }
                    this.post(.didPlayToEnd)
                    this.stop()
            })
        }
    }
}

// MARK: KVO

fileprivate var PlaybackCompositionControllerContext = "PlaybackCompositionControllerContext"

extension PlaybackCompositionController {
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else { return }
        guard let object = object as AnyObject? else { return }
        
        DispatchQueue.main.async {
            if self.player === object {
                if #available(iOS 10.0, *), keyPath == "timeControlStatus" {
                    self.playerDidChangeTimeControlStatus()
                }
                    
                else if keyPath == "rate" {
                    self.playerDidChangeRate()
                }
            }
            
            else if let item = object as? AVPlayerItem {
                
                if item === self.compositedAssetPlayerItem && keyPath == "status" {
                    self.playerItemDidChangeStatus(item)
                }
            }
        }
    }
    
    override func removeObservers() {
        super.removeObservers()
        mainAssetPlayerItem?.remove(observer: self, for: mainAssetPlayerItemKeyPaths, context: &PlaybackCompositionControllerContext)
    }
}
