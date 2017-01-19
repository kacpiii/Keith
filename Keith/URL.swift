//
//  URL.swift
//  Keith
//
//  Created by Rafael Alencar on 19/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation

public extension URL {
    
    private var prefix: String { return "keith" }
    
    /// Adds a scheme prefix to a copy of the receiver.
    func convertToRedirectURL() -> URL? {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        guard let scheme = comps.scheme else { return nil }
        comps.scheme = prefix + scheme
        return comps.url
    }
    
    /// Removes a scheme prefix from a copy of the receiver.
    func convertFromRedirectURL() -> URL? {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        guard let scheme = comps.scheme else { return nil }
        comps.scheme = scheme.replacingOccurrences(of: prefix, with: "")
        return comps.url
    }
}
