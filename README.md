# Keith

[![Build Status](https://travis-ci.org/Movile/Keith.svg?branch=master)](https://travis-ci.org/Movile/Keith)
[![CocoaPods Version](https://cocoapod-badges.herokuapp.com/v/Keith/badge.png)](http://cocoadocs.org/docsets/Keith)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![GitHub release](https://img.shields.io/github/tag/movile/keith.svg)](https://github.com/Movile/Keith/releases)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/Movile/Keith/master/LICENSE.md)

A media player for iOS written in Swift 3.0. Keith was based on the audio player implemented on https://github.com/jaredsinclair/sodes-audio-example.

## Features

* Generic audio and video player for iOS
* Easier than setting up your own AVPlayer stack
* No need to deal with key-value observing AVPlayer and AVPlayerItem properties yourself
* Deals with audio session interruptions for you
* Remote commands for Control Center

Keith does *not* include any UI elements. Only player logic.

## Installation

Using [CocoaPods](http://cocoapods.org/):

```ruby
use_frameworks!
pod 'Keith'
```

Using [Carthage](https://github.com/Carthage/Carthage):

```
github "Movile/Keith"
```

Manually:

1. Drag `Keith.xcodeproj` to your project in the _Project Navigator_.
2. Select your project and then your app target. Open the _Build Phases_ panel.
3. Expand the _Target Dependencies_ group, and add `Keith.framework`.
4. Click on the `+` button at the top left of the panel and select _New Copy Files Phase_. Set _Destination_ to _Frameworks_, and add `Keith.framework`.
5. `import Keith` whenever you want to use Haneke.

## Requirements

- iOS 9.2+
- Swift 3.0

## Usage

To get started, first create a playback source.
```swift
let url = URL(string: "http://devstreaming.apple.com/videos/wwdc/2016/102w0bsn0ge83qfv7za/102/hls_vod_mvp.m3u8")!
let type: PlaybackSource.`Type` = .video

let source = PlaybackSource(url: url, type: type)
```

Then, set up the playback controller, which is Keith's working horse.
```swift
let playbackController = PlaybackController()
playbackController.prepareToPlay(source, playWhenReady: true, startTime: 0.0)
```

You can optionally use the playback controller's `shared` property to obtain a singleton instance. This may be useful when you need to retain the controller in your whole app's lifetime -- audio player app's are a common use case.
```swift
let playbackController = PlaybackController.shared
```

The playback controller supports standard operations (play, pause, toggle play/pause, skip forward/backward, seek) and has a `status` property to check for playback states.

It's possible to get the underlying AVPlayer from the playback controller and use it to include in an AVPlayerViewController, for example.
```swift
import AVKit

let playerViewController = AVPlayerViewController()
playerViewController.player = playbackController.player
```

Observe the following notifications to monitor changes in the playback state.
- didBeginPlayback
- didPausePlayback
- didResumePlayback
- didStopPlayback
- willChangePositionTime
- didChangePositionTime
- didUpdateElapsedTime
- didUpdateDuration
- didUpdateStatus
- didPlayToEnd   
- willChangePlaybackSource
- didChangePlaybackSource

## Name

Keith's name is a homage to Keith Richards, one of the greatest guitar players that ever existed and the embodiment of rock 'n roll itself.

> *If you've gotta think about being cool, you ain' cool*
>
Keith Richards
