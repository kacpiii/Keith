//
//  AudioPlayerViewController.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import Keith

class AudioPlayerViewController: UIViewController {
    
    @IBOutlet private weak var playPauseButton: UIButton?
    @IBOutlet private weak var elapsedTimeLabel: UILabel?
    @IBOutlet private weak var durationLabel: UILabel?
    
    private let playbackController = PlaybackController.shared
    private let playbackCompositionController = PlaybackCompositionController.sharedComposition
    private let artworkProvider = ArtworkProvider()
    private var playerViewController: AVPlayerViewController?
    
    private lazy var simpleAudioSource: PlaybackSource = {
        let nowPlayingInfo = NowPlayingInfo(
            title: "Title name",
            albumTitle: "Album name",
            artist: "Artist name",
            artworkUrl: URL(string: "http://exponent.fm/wp-content/uploads/2014/02/cropped-Exponent-header.png")
        )
        
        let url = URL(string: "http://content.blubrry.com/exponent/exponent86.mp3")!
        let type = PlaybackType.audio(nowPlayingInfo: nowPlayingInfo)
        
        return PlaybackSource(url: url, type: type)
    }()
    
    private lazy var assets: [AVURLAsset]? = {
        guard let url1 = URL(string: "http://content.blubrry.com/exponent/exponent86.mp3") else { return nil }
        guard let url2 = Bundle.main.url(forResource: "sons", withExtension: "m4a") else { return nil }
        
        let urls = [url1, url2]
        let assets = urls.map { AVURLAsset(url: $0) }
        
        return assets
    }()
    
    private lazy var compositionSource: PlaybackComposition? = {
        let nowPlayingInfo = NowPlayingInfo(
            title: "Title name",
            albumTitle: "Album name",
            artist: "Artist name",
            artworkUrl: nil
        )
        
        let type = PlaybackType.audio(nowPlayingInfo: nowPlayingInfo)
        
        guard let assets = self.assets else { return nil }
        
        return PlaybackComposition.overlappingComposition(for: assets, playbackType: type)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCompositionStack()
    }
    
    private func setupPlayerStack() {
        var configuration = PlaybackConfiguration.default
        configuration.playWhenReady = false
        
        playbackController.artworkProvider = artworkProvider
        playbackController.prepareToPlay(simpleAudioSource, configuration: configuration)
        
        let center = NotificationCenter.default
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateStatus.name,
            object: playbackController,
            queue: .main) { _ in
                switch self.playbackController.status {
                case .preparing(_, _):
                    self.playPauseButton?.isEnabled = false
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    
                case .buffering:
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    
                case .playing(_):
                    self.playPauseButton?.setTitle("Pause", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                case .paused(_), .idle:
                    self.playPauseButton?.setTitle("Play", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                case .error(let error):
                    self.playPauseButton?.setTitle("Error", for: .normal)
                    self.playPauseButton?.isEnabled = false
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                    if let error = error {
                        print(error)
                    }
                }
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateElapsedTime.name,
            object: playbackController,
            queue: .main) { _ in
                let elapsedTime = floor(self.playbackController.elapsedTime)
                self.elapsedTimeLabel?.text = TimeParser.string(from: elapsedTime)
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateDuration.name,
            object: playbackController,
            queue: .main) { _ in
                guard let _duration = self.playbackController.duration else { return }
                let duration = floor(_duration)
                self.durationLabel?.text = TimeParser.string(from: duration)
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didPlayToEnd.name,
            object: playbackController,
            queue: .main) { _ in
                print("PlaybackController didPlayToEnd")
        }
    }
    
    private func setupCompositionStack() {
        var configuration = PlaybackConfiguration.default
        configuration.playWhenReady = false
        
        playbackCompositionController.artworkProvider = artworkProvider
        playbackCompositionController.prepareToPlay(compositionSource!, configuration: configuration)
        
        let center = NotificationCenter.default
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateStatus.name,
            object: playbackCompositionController,
            queue: .main) { _ in
                switch self.playbackCompositionController.status {
                case .preparing(_, _):
                    self.playPauseButton?.isEnabled = false
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    
                case .buffering:
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    
                case .playing(_):
                    self.playPauseButton?.setTitle("Pause", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                case .paused(_), .idle:
                    self.playPauseButton?.setTitle("Play", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                case .error(let error):
                    self.playPauseButton?.setTitle("Error", for: .normal)
                    self.playPauseButton?.isEnabled = false
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    
                    if let error = error {
                        print(error)
                    }
                }
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateElapsedTime.name,
            object: playbackCompositionController,
            queue: .main) { _ in
                let elapsedTime = floor(self.playbackCompositionController.elapsedTime)
                self.elapsedTimeLabel?.text = TimeParser.string(from: elapsedTime)
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateDuration.name,
            object: playbackCompositionController,
            queue: .main) { _ in
                guard let _duration = self.playbackCompositionController.duration else { return }
                let duration = floor(_duration)
                self.durationLabel?.text = TimeParser.string(from: duration)
        }
        center.addObserver(
            forName: PlaybackControllerNotification.didPlayToEnd.name,
            object: playbackCompositionController,
            queue: .main) { _ in
                print("PlaybackCompositionController didPlayToEnd")
        }
    }

    
    @IBAction func togglePlayPause(_ playPauseButton: UIButton) {
        playbackCompositionController.togglePlayPause()
    }
}
