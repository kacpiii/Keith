//
//  CMTime.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 09/01/17.
//  Copyright © 2017 movile. All rights reserved.
//

import Foundation
import AVFoundation

internal extension CMTime {
    var asTimeInterval: TimeInterval? {
        if isNumeric {
            return CMTimeGetSeconds(self)
        } else {
            return nil
        }
    }
}
