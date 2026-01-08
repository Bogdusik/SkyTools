//
//  FlightEvent.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import CoreLocation

/// Flight event marker (interesting moment, problem, wind, etc.)
struct FlightEvent: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let timestamp: Date
    let type: EventType
    let note: String?
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    
    enum EventType: String, Codable, CaseIterable {
        case interesting = "Interesting Shot"
        case problem = "Problem"
        case wind = "Wind"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .interesting: return "camera.fill"
            case .problem: return "exclamationmark.triangle.fill"
            case .wind: return "wind"
            case .custom: return "tag.fill"
            }
        }
        
        var color: String {
            switch self {
            case .interesting: return "blue"
            case .problem: return "red"
            case .wind: return "orange"
            case .custom: return "purple"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date = Date(),
        type: EventType,
        note: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.type = type
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}
