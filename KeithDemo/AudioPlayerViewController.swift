//
//  AudioPlayerViewController.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import UIKit
import Keith

class AudioPlayerViewController: UIViewController {
    
    @IBOutlet private weak var playPauseButton: UIButton?
    @IBOutlet private weak var elapsedTimeLabel: UILabel?
    @IBOutlet private weak var durationLabel: UILabel?
    
    private let playbackController = PlaybackController.shared
    private let artworkProvider = ArtworkProvider()
    
    private lazy var source: PlaybackSource = {
        let nowPlayingInfo = PlaybackSource.NowPlayingInfo(
            title: "Title name",
            albumTitle: "Album name",
            artist: "Artist name",
            artworkUrl: URL(string: "http://exponent.fm/wp-content/uploads/2014/02/cropped-Exponent-header.png")
        )
        
        let url = URL(string: "http://content.blubrry.com/exponent/exponent86.mp3")!
        
        let type: PlaybackSource.`Type` = .audio(nowPlayingInfo: nowPlayingInfo)
        let source = PlaybackSource(url: url, type: type)
        
        return source
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPlayerStack()
    }
    
    private func setupPlayerStack() {
        playbackController.artworkProvider = artworkProvider
        playbackController.prepareToPlay(source, playWhenReady: false, startTime: 0.0)
        
        let center = NotificationCenter.default
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateStatus.name,
            object: nil,
            queue: .main) { _ in
                switch self.playbackController.status {
                case .playing(_), .preparing(_, _):
                    self.playPauseButton?.setTitle("Pause", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    
                case .paused(_), .idle, .buffering:
                    self.playPauseButton?.setTitle("Play", for: .normal)
                    self.playPauseButton?.isEnabled = true
                    
                case .error(let error):
                    self.playPauseButton?.setTitle("Error", for: .normal)
                    self.playPauseButton?.isEnabled = false
                    
                    if let error = error {
                        print(error)
                    }
                }
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateElapsedTime.name,
            object: nil,
            queue: .main) { _ in
                let elapsedTime = floor(self.playbackController.elapsedTime)
                self.elapsedTimeLabel?.text = TimeParser.string(from: elapsedTime)
        }
        
        center.addObserver(
            forName: PlaybackControllerNotification.didUpdateDuration.name,
            object: nil,
            queue: .main) { _ in
                guard let _duration = self.playbackController.duration else { return }
                let duration = floor(_duration)
                self.durationLabel?.text = TimeParser.string(from: duration)
        }
    }
    
    @IBAction func togglePlayPause(_ playPauseButton: UIButton) {
        playbackController.togglePlayPause()
    }
}
