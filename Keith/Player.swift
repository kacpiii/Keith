//
//  Player.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 27/10/16.
//  Copyright © 2016 movile. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

enum PlayerNotification: String {
    
    // Playback Notifications
    case didBeginPlayback = "PlayerDidBeginPlayback"
    case didPausePlayback = "PlayerDidPausePlayback"
    case didResumePlayback = "PlayerDidResumePlayback"
    case didStopPlayback = "PlayerDidStopPlayback"
    case willChangePositionTime = "PlayerWillChangePositionTime"
    case didChangePositionTime = "PlayerDidChangePositionTime"
    
    // Update Notifications
    case didUpdateElapsedTime = "PlayerDidUpdateElapsedTime"
    case didUpdateDuration = "PlayerDidUpdateDuration"
    
    // Playback Status Notifications
    case didUpdateStatus = "PlayerDidUpdateStatus"
    case didPlayToEnd = "PlayerDidPlayToEnd"
    
    case willChangeMediaResource = "PlayerWillChangeMediaResource"
    case didChangeMediaResource = "PlayerDidChangeMediaResource"
    
    var name: Notification.Name {
        return Notification.Name(rawValue)
    }
}

class Player: NSObject {
    
    // MARK: Types
    
    /// The various states the controller can be in.
    enum Status {
        
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
    static let shared = Player()
    
    
    // MARK: Public Properties (readonly)
    
    /// The lone AVPlayer
    let player: AVPlayer
    
    /// The current media resource. When changed, a notification is posted.
    fileprivate(set) var mediaResource: MediaResource? {
        willSet {
            NotificationCenter.default.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
            post(.willChangeMediaResource)
        }
        
        didSet {
            currentArtwork = nil
            updateArtwork()
            updateNowPlayingInfo()
            post(.didChangeMediaResource)
        }
    }
    
    /// The current status. When changed, a notification is posted.
    fileprivate(set) var status: Status = .idle {
        didSet {
            updateNowPlayingInfo()
            post(.didUpdateStatus)
        }
    }
    
    /// The current elapsed time. When updated, a notification is posted.
    fileprivate(set) var elapsedTime: TimeInterval = 0 {
        didSet {
            post(.didUpdateElapsedTime)
        }
    }
    
    /// The current duration. When updated, a notification is posted.
    fileprivate(set) var duration: TimeInterval? {
        didSet {
            updateNowPlayingInfo()
            post(.didUpdateDuration)
        }
    }
    
    
    // MARK: Public Properties (read/write)
    
    /// The preferred backward skip interval (in seconds).
    var backwardSkipInterval: TimeInterval = 15  {
        didSet {
            let center = MPRemoteCommandCenter.shared()
            center.skipBackwardCommand.preferredIntervals = [NSNumber(value: backwardSkipInterval)]
        }
    }
    
    /// The preferred forward skip interval (in seconds).
    var forwardSkipInterval: TimeInterval = 30 {
        didSet {
            let center = MPRemoteCommandCenter.shared()
            center.skipForwardCommand.preferredIntervals = [NSNumber(value: forwardSkipInterval)]
        }
    }
    

    // MARK: File Private Properties
    
    /// The current AVPlayerItem.
    fileprivate var currentPlayerItem: AVPlayerItem? {
        willSet {
            removeCommandHandlers()
        }
        
        didSet {
            didSetPlayerItem(oldValue: oldValue)
            registerCommandHandlers()
        }
    }
    
    /// The current artwork, if any.
    fileprivate var currentArtwork: UIImage? = nil {
        didSet {
            updateNowPlayingInfo()
        }
    }
    
    /// The audio session.
    fileprivate let audioSession = AVAudioSession.sharedInstance()
    
    /// The delegate for the asset resource loader.
    fileprivate var assetResourceLoaderDelegate: AVAssetResourceLoaderDelegate?
    
    /// The queue used by the asset resource loader delegate.
    fileprivate let queue = DispatchQueue(label: "com.movile.vivolearning.player.assetResourceLoaderDelegate", attributes: [])
    
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
    
    override init() {
        self.player = AVPlayer()
        
        super.init()
        
        try? audioSession.setCategory(AVAudioSessionCategoryPlayback)
        try? audioSession.setMode(AVAudioSessionModeSpokenAudio)
        
        if #available(iOS 10, *) {
            // Since we are using a custom asset resource delegate, disable `automaticallyWaitsToMinimizeStalling` as recommended by Apple in the documentation.
            player.automaticallyWaitsToMinimizeStalling = false
        }
        
        player.add(observer: self, for: playerKeyPaths, options: .new, context: &PlayerContext)
        
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
        mediaResource = nil
        currentPlayerItem = nil
        assetResourceLoaderDelegate = nil
        
        removeTimeObserver()
        removeCommandHandlers()
        removeObservers()
    }
    
    
    // MARK: Public methods
    
    func prepareToPlay(_ mediaResource: MediaResource, playWhenReady: Bool = false, startTime: TimeInterval = 0) {
        
        if case .playing = status, playWhenReady == false {
            pause(manually: true)
        }
        
        self.mediaResource = mediaResource
        self.currentPlayerItem = nil
        self.player.replaceCurrentItem(with: nil)
        self.status = .preparing(playWhenReady: playWhenReady, startTime: startTime)
            
        let asset = AVURLAsset(url: mediaResource.encryptedUrl!)
        
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let this = self else { return }
                
                var error: NSError?
                let keyStatus = asset.statusOfValue(forKey: "playable", error: &error)
                
                if keyStatus == .failed {
                    KeithLog("Error when obtaining `playable` key for resource: \(error?.localizedDescription)")
                    
                    this.status = .error(error)
                    return
                }
                
                this.currentPlayerItem = AVPlayerItem(asset: asset)
                this.player.replaceCurrentItem(with: this.currentPlayerItem!)
                
                this.registerCommandHandlers()
                this.registerForAudioSessionInterruptionNotification()
                this.updateArtwork()
                this.updateNowPlayingInfo()
            }
        }
    }
    
    func play() {
        guard !isInterrupted else { return }
        
        switch status {
        case .paused, .preparing:
            status = .playing(fromBeginning: isPlayingFromBeginning)
            player.play()
            
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
    
    func pause(manually: Bool) {
        switch status {
        case .preparing(let playWhenReady, let startTime):
            if playWhenReady {
                status = .preparing(playWhenReady: false, startTime: startTime)
            }
        
        case .playing, .buffering:
            status = .paused(manually: manually)
            player.pause()
            post(.didPausePlayback)
        
        case .idle, .paused, .error:
            break
        }
    }
    
    func togglePlayPause() {
        switch status {
        case .playing:
            pause(manually: true)
        
        case .paused:
            play()
            
        case .idle, .buffering, .preparing(_, _), .error(_):
            break
        }
    }
    
    func stop() {
        switch status {
        case .playing, .buffering:
            pause(manually: true)
            seekToTime(0.0, accurately: true) {
                self.post(.didStopPlayback)
            }
            
        case .paused, .idle, .preparing, .error:
            status = .idle
            seekToTime(0.0, accurately: true)
        }
        
        isPlayingFromBeginning = true
    }
    
    func skipForward() {
        let newTime = elapsedTime + forwardSkipInterval
        seekToTime(newTime, accurately: true)
    }
    
    func skipBackward() {
        let newTime = elapsedTime - backwardSkipInterval
        seekToTime(newTime, accurately: true)
    }
    
    func seekToTime(_ time: TimeInterval, accurately: Bool = true, completion: @escaping () -> Void = {}) {
        guard player.currentItem != nil else { return }
        
        post(.willChangePositionTime)
        
        if accurately {
            player.seek(
                to: time.asCMTime,
                toleranceBefore: kCMTimeZero,
                toleranceAfter: kCMTimeZero,
                completionHandler: { [weak self] (finished) in
                    if finished {
                        self?.updateNowPlayingInfo()
                        completion()
                        self?.post(.didChangePositionTime)
                    }
                }
            )
        } else {
            player.seek(to: time.asCMTime) { [weak self] (finished) in
                if finished {
                    self?.updateNowPlayingInfo()
                    self?.post(.didChangePositionTime)
                }
            }
        }
    }
}


// MARK: Private methods

private extension Player {
    func post(_ notification: PlayerNotification, userInfo: [String: Any]? = nil) {
        let note = Notification(name: notification.name, object: self, userInfo: userInfo)
        NotificationCenter.default.post(note)
    }
    
    func didSetPlayerItem(oldValue: AVPlayerItem?) {
        oldValue?.remove(observer: self, for: playerItemKeyPaths, context: &PlayerContext)
        currentPlayerItem?.add(observer: self, for: playerItemKeyPaths, context: &PlayerContext)
        currentPlayerItem?.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain
        
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
                    this.post(.didPlayToEnd)
                    this.stop()
            })
        }
    }
    
    func registerForAudioSessionInterruptionNotification() {
        if let mediaResource = mediaResource, case .audio = mediaResource.type {
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
        
        updateNowPlayingInfo()
    }
    
    func playerDidChangeRate() {
        let stoppedRate = Float(0.0)
        
        switch (player.rate, status) {
        case (stoppedRate, .playing):
            // Rate indicates playback is stopped, but our status doesn't reflect that.
            status = .paused(manually: true)
            
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
            KeithLog("Item status failed: \(item.error)")
            status = .error(item.error)
            
        case .unknown:
            KeithLog("Item status unknown")
            status = .error(nil)
        }
    }
    
    func updateNowPlayingInfo() {
        guard let mediaResource = mediaResource, case .audio = mediaResource.type else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let mediaType: NSNumber
        
        switch mediaResource.type {
        case .audio:
            mediaType = NSNumber(value: MPMediaType.anyAudio.rawValue)
            
        case .video:
            mediaType = NSNumber(value: MPMediaType.anyVideo.rawValue)
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyMediaType: mediaType,
            MPMediaItemPropertyTitle: mediaResource.className,
            MPMediaItemPropertyAlbumTitle: mediaResource.courseName,
            MPMediaItemPropertyArtist: mediaResource.producerName,
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: duration ?? 0.0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: elapsedTime),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: player.rate),
        ]
        
        if let currentArtwork = currentArtwork {
            if #available(iOS 10.0, *) {
                let artwork = MPMediaItemArtwork(boundsSize: currentArtwork.size) { inputSize -> UIImage in
                    return currentArtwork.draw(at: inputSize)
                }
                
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func updateArtwork() {
        guard let mediaResource = mediaResource, case .audio = mediaResource.type else {
            self.currentArtwork = nil
            return
        }
        
        mediaResource.getArtwork { [weak self] image in
            self?.currentArtwork = image
        }
    }
    
    func removeTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
}


// MARK: KVO

fileprivate var PlayerContext = "PlayerContext"

extension Player {
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
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
        player.remove(observer: self, for: playerKeyPaths, context: &PlayerContext)
        currentPlayerItem?.remove(observer: self, for: playerItemKeyPaths, context: &PlayerContext)
    }
}


// MARK: Remote Commands

extension Player {
    func registerCommandHandlers() {
        guard let mediaResource = mediaResource, case .audio = mediaResource.type else {
            removeCommandHandlers()
            return
        }
        
        let center = MPRemoteCommandCenter.shared()
        
        // Playback Commands
        center.playCommand.addTarget(handler: handlePlayCommand)
        center.pauseCommand.addTarget(handler: handlePauseCommand)
        center.stopCommand.isEnabled = false
        center.togglePlayPauseCommand.addTarget(handler: handleTogglePlayPauseCommand)
        
        // Changing Tracks
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        
        // Navigating a Track's Contents
        center.seekBackwardCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.changePlaybackRateCommand.isEnabled = false
        center.skipBackwardCommand.addTarget(handler: handleSkipBackwardCommand)
        center.skipForwardCommand.addTarget(handler: handleSkipForwardCommand)
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: backwardSkipInterval)]
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: forwardSkipInterval)]
        center.changePlaybackPositionCommand.addTarget(handler: handleChangePlaybackPositionCommand)
        
        // Other
        center.ratingCommand.isEnabled = false
        center.likeCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.bookmarkCommand.isEnabled = false
    }
    
    func removeCommandHandlers() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
    }
    
    func handlePlayCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing:
            return .success
            
        case .paused:
            play()
            return .success
            
        case .idle, .buffering, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
    
    func handlePauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing:
            pause(manually: true)
            return .success
            
        case .paused(_):
            status = .paused(manually: true)
            return .success
            
        case .idle, .buffering, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
    
    func handleTogglePlayPauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing:
            return handlePauseCommand(event)
            
        case .paused:
            return handlePlayCommand(event)
            
        case .idle, .buffering, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
    
    func handleSkipBackwardCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing, .paused, .buffering:
            skipBackward()
            return .success
            
        case .idle, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
    
    func handleSkipForwardCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing, .paused, .buffering:
            skipForward()
            return .success
            
        case .idle, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
    
    func handleChangePlaybackPositionCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch status {
        case .playing, .paused, .buffering:
            let positionTime = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0.0
            seekToTime(positionTime, accurately: true)
            return .success
            
        case .idle, .preparing(_,_), .error(_):
            return .noActionableNowPlayingItem
        }
    }
}

