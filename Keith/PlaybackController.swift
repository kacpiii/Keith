//
//  PlaybackController.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

public enum PlaybackControllerNotification: String {
    
    // Playback Notifications
    case didBeginPlayback = "PlaybackControllerDidBeginPlayback"
    case didPausePlayback = "PlaybackControllerDidPausePlayback"
    case didResumePlayback = "PlaybackControllerDidResumePlayback"
    case didStopPlayback = "PlaybackControllerDidStopPlayback"
    case willChangePositionTime = "PlaybackControllerWillChangePositionTime"
    case didChangePositionTime = "PlaybackControllerDidChangePositionTime"
    
    // Update Notifications
    case didUpdateElapsedTime = "PlaybackControllerDidUpdateElapsedTime"
    case didUpdateDuration = "PlaybackControllerDidUpdateDuration"
    
    // Playback Status Notifications
    case didUpdateStatus = "PlaybackControllerDidUpdateStatus"
    case didPlayToEnd = "PlaybackControllerDidPlayToEnd"
    
    case willChangePlaybackSource = "PlaybackControllerWillChangePlaybackSource"
    case didChangePlaybackSource = "PlaybackControllerDidChangePlaybackSource"
    
    public var name: Notification.Name {
        return Notification.Name(rawValue)
    }
}

public class PlaybackController: NSObject {
    
    // MARK: Types
    
    /// The various states the controller can be in.
    public enum Status {
        
        /// Has no current item.
        case idle
        
        /// Preparing the current item.
        case preparing(playWhenReady: Bool, startTime: TimeInterval)
        
        /// Audio or video is playing.
        case playing(fromBeginning: Bool)
        
        /// Data is being buffered, playback is temporarily suspended.
        case buffering
        
        /// Playback is paused.
        case paused(manually: Bool)
        
        /// Playback encountered an unrecoverable error.
        case error(Error?)
    }
    
    
    // MARK: Singleton
    
    /// The singleton instance. Optional.
    public static let shared = PlaybackController()
    
    // MARK: Delegates & Data Sources
    
    // MARK: Public Properties (readonly)
    
    /// The lone AVPlayer
    public let player: AVPlayer
    
    /// The current playback source. When changed, a notification is posted.
    public fileprivate(set) var playbackSource: PlaybackSource? {
        willSet {
            NotificationCenter.default.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
            post(.willChangePlaybackSource)
        }
        
        didSet {
            post(.didChangePlaybackSource)
        }
    }
    
    /// The current status. When changed, a notification is posted.
    public fileprivate(set) var status: Status = .idle {
        didSet {
            post(.didUpdateStatus)
        }
    }
    
    /// The current elapsed time. When updated, a notification is posted.
    public fileprivate(set) var elapsedTime: TimeInterval = 0 {
        didSet {
            post(.didUpdateElapsedTime)
        }
    }
    
    /// The current duration. When updated, a notification is posted.
    public fileprivate(set) var duration: TimeInterval? {
        didSet {
            post(.didUpdateDuration)
        }
    }
    
    
    // MARK: Public Properties (read/write)
    
    /// The preferred backward skip interval (in seconds).
    public var backwardSkipInterval: TimeInterval = 15  {
        didSet {
            let center = MPRemoteCommandCenter.shared()
            center.skipBackwardCommand.preferredIntervals = [NSNumber(value: backwardSkipInterval)]
        }
    }
    
    /// The preferred forward skip interval (in seconds).
    public var forwardSkipInterval: TimeInterval = 30 {
        didSet {
            let center = MPRemoteCommandCenter.shared()
            center.skipForwardCommand.preferredIntervals = [NSNumber(value: forwardSkipInterval)]
        }
    }
    
    /// The audioMix.
    public var audioMix: AVAudioMix? {
        didSet {
            currentPlayerItem?.audioMix = audioMix
        }
    }
    
    
    // MARK: File Private Properties
    
    /// The current AVPlayerItem.
    fileprivate var currentPlayerItem: AVPlayerItem? {
        didSet {
            didSetPlayerItem(oldValue: oldValue)
        }
    }
    
    /// The audio session.
    fileprivate let audioSession = AVAudioSession.sharedInstance()
    
    /// The delegate for the asset resource loader.
    fileprivate var resourceLoaderDelegate: AVAssetResourceLoaderDelegate?
    
    /// The queue used by the asset resource loader delegate.
    fileprivate let queue = DispatchQueue(label: "com.movile.keith.player.assetResourceLoaderDelegate", attributes: [])
    
    /// Indicates whether the player is being interrupted by system audio.
    fileprivate var isInterrupted = false
    
    /// An observer for observing the player's elapsed time.
    fileprivate var currentPlayerItemObserver: NSObjectProtocol?
    
    /// The token returned by the periodic time observer
    fileprivate var timeObserverToken: Any?
    
    /// The preferred time interval for elapsed time callbacks.
    fileprivate let periodicTimeInterval = TimeInterval(1.0/30.0).asCMTime
    
    /// Indicates whether the current playback has started from the beginning.
    fileprivate var isPlayingFromBeginning = true
    
    /// AVPlayer keypaths to be observed using KVO.
    fileprivate let playerKeyPaths: [String] = ["timeControlStatus", "rate"]
    
    /// AVPlayerItem keypaths to be observed using KVO.
    fileprivate let playerItemKeyPaths: [String] = ["status", "duration"]
    
    // MARK: Init/Deinit
    
    public override init() {
        self.player = AVPlayer()
        
        super.init()
        
        try? audioSession.setCategory(AVAudioSessionCategoryPlayback)
        
        player.add(observer: self, for: playerKeyPaths, options: .new, context: &PlaybackControllerContext)
        
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: periodicTimeInterval,
            queue: DispatchQueue.main) { [weak self] time in
                DispatchQueue.main.async {
                    guard let this = self else { return }
                    if let elapsedTime = time.asTimeInterval {
                        this.elapsedTime = elapsedTime
                    }
                }
        }
    }
    
    deinit {
        removeTimeObserver()
        removeObservers()
        
        playbackSource = nil
        currentPlayerItem = nil
        resourceLoaderDelegate = nil
    }
    
    
    // MARK: Public methods
    
    public func prepareToPlay(
        _ playbackSource: PlaybackSource,
        configuration: PlaybackConfiguration = .default) {
        
        if case .playing = status, configuration.playWhenReady == false {
            pause(manually: true)
        }
        
        self.playbackSource = playbackSource
        self.currentPlayerItem = nil
        self.player.replaceCurrentItem(with: nil)
        self.status = .preparing(playWhenReady: configuration.playWhenReady, startTime: configuration.startTime)
        
        guard let asset = asset(for: playbackSource, configuration: configuration) else { return }
        
        if #available(iOS 10, *) {
            player.automaticallyWaitsToMinimizeStalling = configuration.automaticallyWaitsToMinimizeStalling
        }
        
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let this = self else { return }
                
                var error: NSError?
                let keyStatus = asset.statusOfValue(forKey: "playable", error: &error)
                
                if keyStatus == .failed {
                    let errorDescription = error?.localizedDescription ?? ""
                    KeithLog("Error when obtaining `playable` key for resource: \(errorDescription)")
                    
                    this.status = .error(error)
                    return
                }
                
                this.currentPlayerItem = AVPlayerItem(asset: asset)
                this.player.replaceCurrentItem(with: this.currentPlayerItem!)
                
                this.registerForAudioSessionInterruptionNotification()
            }
        }
    }
    
    private func asset(for playbackSource: PlaybackSource, configuration: PlaybackConfiguration) -> AVAsset? {
        
        // If a custom resource loader delegate is being used,
        // convert the URL to use a custom scheme so that the
        // delegate will be called by AVFoundation.
        if let resourceLoaderDelegate = configuration.resourceLoaderDelegate,
            let url = playbackSource.url?.convertToRedirectURL() {
            
            let asset = AVURLAsset(url: url)
            asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: queue)
            self.resourceLoaderDelegate = resourceLoaderDelegate
            return asset
        
        } else {
            return playbackSource.asset
        }
    }
    
    public func play() {
        guard !isInterrupted else { return }
        
        switch status {
        case .paused, .preparing:
            player.play()
            status = .playing(fromBeginning: isPlayingFromBeginning)
            
            if isPlayingFromBeginning {
                post(.didBeginPlayback)
                isPlayingFromBeginning = false
                
            } else {
                post(.didResumePlayback)
            }
            
        case .idle, .playing, .buffering, .error:
            break
        }
    }
    
    public func pause(manually: Bool) {
        switch status {
        case .preparing(let playWhenReady, let startTime):
            if playWhenReady {
                status = .preparing(playWhenReady: false, startTime: startTime)
            }
            
        case .playing, .buffering:
            player.pause()
            status = .paused(manually: manually)
            post(.didPausePlayback)
            
        case .idle, .paused, .error:
            break
        }
    }
    
    public func togglePlayPause() {
        switch status {
        case .playing:
            pause(manually: true)
            
        case .paused:
            play()
            
        case .idle, .buffering, .preparing(_, _), .error(_):
            break
        }
    }
    
    public func stop(completion: @escaping () -> Void = {}) {
        switch status {
        case .playing, .buffering:
            pause(manually: true)
            
            seekToTime(0.0, accurately: true) {
                self.post(.didStopPlayback)
                completion()
            }
            
        case .paused, .idle, .preparing, .error:
            seekToTime(0.0, accurately: true) {
                completion()
            }
        }
        
        isPlayingFromBeginning = true
    }
    
    public func skipForward(completion: @escaping () -> Void = {}) {
        let newTime = elapsedTime + forwardSkipInterval
        seekToTime(newTime, accurately: true, completion: completion)
    }
    
    public func skipBackward(completion: @escaping () -> Void = {}) {
        let newTime = elapsedTime - backwardSkipInterval
        seekToTime(newTime, accurately: true, completion: completion)
    }
    
    public func seekToTime(_ time: TimeInterval, accurately: Bool = true, completion: @escaping () -> Void = {}) {
        guard player.currentItem != nil else { return }
        
        post(.willChangePositionTime)
        
        if accurately {
            player.seek(
                to: time.asCMTime,
                toleranceBefore: kCMTimeZero,
                toleranceAfter: kCMTimeZero,
                completionHandler: { [weak self] finished in
                    guard finished else { return }
                    completion()
                    self?.post(.didChangePositionTime)
                }
            )
        } else {
            player.seek(to: time.asCMTime) { [weak self] finished in
                guard finished else { return }
                self?.post(.didChangePositionTime)
            }
        }
    }
}


// MARK: Private methods

private extension PlaybackController {
    func post(_ notification: PlaybackControllerNotification, userInfo: [String: Any]? = nil) {
        let note = Notification(name: notification.name, object: self, userInfo: userInfo)
        NotificationCenter.default.post(note)
    }
    
    func didSetPlayerItem(oldValue: AVPlayerItem?) {
        oldValue?.remove(observer: self, for: playerItemKeyPaths, context: &PlaybackControllerContext)
        currentPlayerItem?.add(observer: self, for: playerItemKeyPaths, context: &PlaybackControllerContext)
        currentPlayerItem?.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithm.timeDomain
        
        if let observer = currentPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let item = currentPlayerItem {
            currentPlayerItemObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main,
                using: { [weak self] (note) in
                    guard let this = self else { return }
                    this.stop {
                        this.post(.didPlayToEnd)
                    }
            })
        }
    }
    
    func registerForAudioSessionInterruptionNotification() {
        if let playbackSource = playbackSource, case .audio = playbackSource.type {
            NotificationCenter.default.addObserver(
                forName: .AVAudioSessionInterruption,
                object: audioSession,
                queue: .main,
                using: handleAudioSessionInterruptionNotification
            )
        }
    }
    
    func handleAudioSessionInterruptionNotification(note: Notification) {
        guard let typeNumber = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
        guard let type = AVAudioSessionInterruptionType(rawValue: typeNumber.uintValue) else { return }
        
        switch type {
            
        case .began:
            isInterrupted = true
            
        case .ended:
            isInterrupted = false
            let optionNumber = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber
            
            if let number = optionNumber {
                let options = AVAudioSessionInterruptionOptions(rawValue: number.uintValue)
                let shouldResume = options.contains(.shouldResume)
                
                switch status {
                case .playing:
                    if shouldResume {
                        play()
                        
                    } else {
                        pause(manually: false)
                    }
                    
                case .paused(let manually):
                    if manually {
                        // Do not resume! The user manually paused.
                        
                    } else {
                        if shouldResume {
                            play()
                        }
                    }
                    
                case .preparing(_, let startTime):
                    status = .preparing(playWhenReady:shouldResume, startTime: startTime)
                    
                case .idle, .error(_), .buffering:
                    break
                }
                
            } else {
                switch status {
                case .playing:
                    play()
                    
                case .paused(let manually):
                    if manually {
                        // Do not resume! The user manually paused.
                        
                    } else {
                        play()
                    }
                    
                case .idle, .buffering, .preparing(_,_), .error(_):
                    break
                }
            }
        }
    }
    
    @available(iOS 10.0, *)
    func playerDidChangeTimeControlStatus() {
        switch player.timeControlStatus {
        case .paused:
            switch status {
            case .paused(_), .idle, .error(_), .preparing(_,_):
                break
            case .playing, .buffering:
                status = .paused(manually: false)
            }
            
        case .playing:
            status = .playing(fromBeginning: isPlayingFromBeginning)
            
        case .waitingToPlayAtSpecifiedRate:
            switch status {
            case .idle, .error(_), .preparing(_,_):
                break
            case .paused, .playing, .buffering:
                status = .buffering
            }
        }
    }
    
    func playerDidChangeRate() {
        let stoppedRate = Float(0.0)
        
        switch (player.rate, status) {
        case (stoppedRate, .playing):
            // Rate indicates playback is stopped, but our status doesn't reflect that.
            status = .paused(manually: false)
            
        case (stoppedRate, _):
            // Rate indicates playback is stopped and our status is not playing, so we're good.
            break
            
        case (_, .playing):
            // Rate indicates audio or video is being played and our status the same, so we're good.
            break
            
        case (_, _):
            // Rate indicates audio or video is being played, but our status doesn't reflect that.
            status = .playing(fromBeginning: isPlayingFromBeginning)
        }
    }
    
    func playerItemDidChangeStatus(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            if case .preparing(let shouldPlay, let startTime) = status {
                if startTime > 0 {
                    seekToTime(startTime, accurately: true) { [weak self] in
                        guard let this = self else {return}
                        if shouldPlay {
                            this.play()
                        } else {
                            this.status = .paused(manually: true)
                        }
                    }
                }
                else if shouldPlay {
                    play()
                } else {
                    status = .paused(manually: true)
                }
            }
            
        case .failed:
            let errorDescription = item.error?.localizedDescription ?? ""
            KeithLog("Item status failed: \(errorDescription)")
            status = .error(item.error)
            
        case .unknown:
            KeithLog("Item status unknown")
            status = .error(nil)
        }
    }
    
    func removeTimeObserver() {
        guard let timeObserverToken = timeObserverToken else { return }
        player.removeTimeObserver(timeObserverToken)
        self.timeObserverToken = nil
    }
}


// MARK: KVO

fileprivate var PlaybackControllerContext = "PlaybackControllerContext"

extension PlaybackController {
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
                guard item === self.currentPlayerItem else { return }
                
                if keyPath == "status" {
                    self.playerItemDidChangeStatus(item)
                }
                    
                else if keyPath == "duration" {
                    if item.duration.isNumeric {
                        self.duration = TimeInterval(CMTimeGetSeconds(item.duration))
                        
                    } else {
                        self.duration = nil
                    }
                }
            }
        }
    }
    
    func removeObservers() {
        player.remove(observer: self, for: playerKeyPaths, context: &PlaybackControllerContext)
        currentPlayerItem?.remove(observer: self, for: playerItemKeyPaths, context: &PlaybackControllerContext)
    }
}
