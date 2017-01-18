//
//  NSObject.swift
//  Vivo Learning
//
//  Created by Rafael Alencar on 09/01/17.
//  Copyright © 2017 movile. All rights reserved.
//

import Foundation

// MARK: KVO convenience helpers

internal extension NSObject {
    func add(observer: NSObject, for keypaths: [String], options: NSKeyValueObservingOptions = .new, context: UnsafeMutableRawPointer) {
        for path in keypaths {
            addObserver(observer, forKeyPath: path, options: options, context: context)
        }
    }
    
    func remove(observer: NSObject, for keypaths: [String], options: NSKeyValueObservingOptions = .new, context: UnsafeMutableRawPointer) {
        for path in keypaths {
            removeObserver(observer, forKeyPath: path, context: context)
        }
    }
}
