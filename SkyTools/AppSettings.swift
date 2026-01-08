//
//  AppSettings.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import SwiftUI
import Combine

/// Application settings manager
@MainActor
final class AppSettings: ObservableObject {
    
    static let shared = AppSettings()
    
    // MARK: - Logging Frequency
    
    @Published var loggingFrequency: LoggingFrequency = .hz2 {
        didSet {
            UserDefaults.standard.set(loggingFrequency.rawValue, forKey: "loggingFrequency")
        }
    }
    
    enum LoggingFrequency: String, CaseIterable {
        case hz1 = "1 Hz"
        case hz2 = "2 Hz"
        case hz5 = "5 Hz"
        
        var interval: TimeInterval {
            switch self {
            case .hz1: return 1.0
            case .hz2: return 0.5
            case .hz5: return 0.2
            }
        }
        
        var displayName: String {
            rawValue
        }
    }
    
    // MARK: - Units
    
    @Published var speedUnit: SpeedUnit = .kmh {
        didSet {
            UserDefaults.standard.set(speedUnit.rawValue, forKey: "speedUnit")
        }
    }
    
    enum SpeedUnit: String, CaseIterable {
        case ms = "m/s"
        case kmh = "km/h"
        
        var displayName: String {
            rawValue
        }
    }
    
    @Published var altitudeUnit: AltitudeUnit = .meters {
        didSet {
            UserDefaults.standard.set(altitudeUnit.rawValue, forKey: "altitudeUnit")
        }
    }
    
    enum AltitudeUnit: String, CaseIterable {
        case meters = "m"
        case feet = "ft"
        
        var displayName: String {
            rawValue
        }
    }
    
    // MARK: - Session Management
    
    @Published var autoStartSession: Bool = true {
        didSet {
            UserDefaults.standard.set(autoStartSession, forKey: "autoStartSession")
        }
    }
    
    @Published var autoEndSession: Bool = true {
        didSet {
            UserDefaults.standard.set(autoEndSession, forKey: "autoEndSession")
        }
    }
    
    // MARK: - Event Markers
    
    @Published var eventMarkersEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(eventMarkersEnabled, forKey: "eventMarkersEnabled")
        }
    }
    
    private init() {
        // Load saved values from UserDefaults
        if let freqRaw = UserDefaults.standard.string(forKey: "loggingFrequency"),
           let freq = LoggingFrequency(rawValue: freqRaw) {
            loggingFrequency = freq
        }
        
        if let speedRaw = UserDefaults.standard.string(forKey: "speedUnit"),
           let speed = SpeedUnit(rawValue: speedRaw) {
            speedUnit = speed
        }
        
        if let altRaw = UserDefaults.standard.string(forKey: "altitudeUnit"),
           let alt = AltitudeUnit(rawValue: altRaw) {
            altitudeUnit = alt
        }
        
        autoStartSession = UserDefaults.standard.bool(forKey: "autoStartSession")
        autoEndSession = UserDefaults.standard.bool(forKey: "autoEndSession")
        eventMarkersEnabled = UserDefaults.standard.bool(forKey: "eventMarkersEnabled")
    }
}
