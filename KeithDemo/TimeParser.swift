//
//  TimeParser.swift
//  Keith
//
//  Created by Rafael Alencar on 17/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import Foundation

struct TimeParser {
    
    private static let calendar = Calendar(identifier: .gregorian)
    
    private static let hourMinuteSecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    private static let minuteSecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()
    
    static func string(from duration: TimeInterval) -> String {
        
        guard duration > 0 else { return "00:00" }
        
        let maximumDuration: TimeInterval = 23*3600 + 59*60 + 59
        guard duration <= maximumDuration else { return "23:59:59" }
        
        let hours = floor(duration / 3600)
        let minutesAndSeconds = duration.truncatingRemainder(dividingBy: 3600)
        let minutes = floor(minutesAndSeconds / 60)
        let seconds = floor(minutesAndSeconds.truncatingRemainder(dividingBy: 60))
        
        var comps = DateComponents()
        comps.calendar = calendar
        comps.day = 1
        comps.month = 1
        comps.year = 2016
        comps.hour = Int(hours)
        comps.minute = Int(minutes)
        comps.second = Int(seconds)
        
        guard let date = comps.date else { return "00:00" }
        
        if hours > 0 {
            let result = hourMinuteSecondFormatter.string(from: date)
            return result
            
        } else {
            let result = minuteSecondFormatter.string(from: date)
            return result
        }
    }
    
    private init() {}
}
