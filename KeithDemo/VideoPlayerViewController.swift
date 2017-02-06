//
//  VideoPlayerViewController.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import UIKit
import AVKit
import Keith

class VideoPlayerViewController: UIViewController {
    
    private var playbackController = PlaybackController.shared
    private var playerViewController: AVPlayerViewController?
    
    private lazy var source: PlaybackSource = {
        let url = URL(string: "http://devstreaming.apple.com/videos/wwdc/2016/102w0bsn0ge83qfv7za/102/hls_vod_mvp.m3u8")!
        
        let type = PlaybackType.video
        let source = PlaybackSource(url: url, type: type)
        
        return source
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPlayerStack()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        playbackController.pause(manually: false)
    }
    
    private func setupPlayerStack() {
        playbackController = PlaybackController.shared
        playerViewController = AVPlayerViewController()
        playerViewController?.player = playbackController.player
        
        // Setting playback controls to `false` in order to avoid
        // unsatisfiable constraint logs: http://stackoverflow.com/a/33042804/1782615
        playerViewController?.showsPlaybackControls = false
        
        guard let playerViewController = playerViewController,
            let playerView = playerViewController.view else { return }

        addChildViewController(playerViewController)
        view.addSubview(playerView)
        
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        playerView.heightAnchor.constraint(equalToConstant: 300).isActive = true
        
        NotificationCenter.default.addObserver(
            forName: PlaybackControllerNotification.didUpdateStatus.name,
            object: nil,
            queue: .main) { _ in
                switch self.playbackController.status {
                case .playing(_), .paused(_), .buffering:
                    self.playerViewController?.showsPlaybackControls = true
                    
                case .idle, .preparing(_, _):
                    break
                    
                case .error(let error):
                    guard let error = error else { return }
                    print(error)
                }
        }
        
        let configuration = PlaybackConfiguration.default

        playbackController.prepareToPlay(source, configuration: configuration)
    }
}
