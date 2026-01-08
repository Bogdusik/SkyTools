//
//  TelemetryRecord.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import CoreLocation

/// Telemetry record model for flight logging
struct TelemetryRecord: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let timestamp: Date
    
    // Telemetry data
    let battery: Int?
    let satellites: Int?
    let altitude: Double?
    let speed: Double?
    let latitude: Double?
    let longitude: Double?
    let heading: Double?
    let gpsSignalLevel: Int?
    let rcSignalLevel: Int?
    let homeLatitude: Double?
    let homeLongitude: Double?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date = Date(),
        battery: Int? = nil,
        satellites: Int? = nil,
        altitude: Double? = nil,
        speed: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        heading: Double? = nil,
        gpsSignalLevel: Int? = nil,
        rcSignalLevel: Int? = nil,
        homeLatitude: Double? = nil,
        homeLongitude: Double? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.battery = battery
        self.satellites = satellites
        self.altitude = altitude
        self.speed = speed
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.gpsSignalLevel = gpsSignalLevel
        self.rcSignalLevel = rcSignalLevel
        self.homeLatitude = homeLatitude
        self.homeLongitude = homeLongitude
    }
}

// MARK: - Legacy TelemetryEntry (for backward compatibility during transition)
extension TelemetryEntry {
    func toTelemetryRecord(sessionId: UUID) -> TelemetryRecord {
        TelemetryRecord(
            sessionId: sessionId,
            timestamp: timestamp,
            battery: battery,
            satellites: satellites,
            altitude: altitude,
            speed: speed,
            latitude: latitude,
            longitude: longitude,
            heading: heading
        )
    }
}
