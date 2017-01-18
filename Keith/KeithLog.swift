//
//  KeithLog.swift
//  Keith
//
//  Created by Rafael Alencar on 16/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation

internal func KeithLog(_ input: Any = "", file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        print("\n\(Date())\n\(file):\n\(function)() Line \(line)\n\(input)\n\n")
    #endif
}
