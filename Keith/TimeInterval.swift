//
//  TimeInterval.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 09/01/17.
//  Copyright © 2017 movile. All rights reserved.
//

import Foundation
import AVFoundation

let preferredTimescale: Int32 = 10000

internal extension TimeInterval {
    var asCMTime: CMTime {
        return CMTimeMakeWithSeconds(self, preferredTimescale)
    }
}
