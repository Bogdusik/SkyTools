//
//  FlightSummary.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation

/// Flight summary with analytics calculations
struct FlightSummary: Identifiable {
    let id: UUID
    let sessionId: UUID
    let startTime: Date
    let endTime: Date?
    
    // Calculated metrics
    let maxAltitude: Double?
    let maxSpeed: Double?
    let avgSpeed: Double?
    let flightDuration: TimeInterval
    let totalDistance: Double?
    let batteryStart: Int?
    let batteryEnd: Int?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        startTime: Date,
        endTime: Date? = nil,
        records: [TelemetryRecord]
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        
        // Calculate metrics from records
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        
        // Max altitude
        self.maxAltitude = sortedRecords
            .compactMap { $0.altitude }
            .max()
        
        // Max speed
        self.maxSpeed = sortedRecords
            .compactMap { $0.speed }
            .max()
        
        // Average speed
        let speeds = sortedRecords.compactMap { $0.speed }
        if !speeds.isEmpty {
            self.avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        } else {
            self.avgSpeed = nil
        }
        
        // Flight duration
        if let endTime = endTime {
            self.flightDuration = endTime.timeIntervalSince(startTime)
        } else if let lastRecord = sortedRecords.last {
            self.flightDuration = lastRecord.timestamp.timeIntervalSince(startTime)
        } else {
            self.flightDuration = 0
        }
        
        // Total distance (calculated from GPS coordinates)
        var totalDistance: Double = 0
        var previousLocation: (lat: Double, lon: Double)?
        
        for record in sortedRecords {
            guard let lat = record.latitude, let lon = record.longitude else { continue }
            
            if let prev = previousLocation {
                let distance = Self.calculateDistance(
                    lat1: prev.lat, lon1: prev.lon,
                    lat2: lat, lon2: lon
                )
                totalDistance += distance
            }
            previousLocation = (lat, lon)
        }
        
        self.totalDistance = totalDistance > 0 ? totalDistance : nil
        
        // Battery start/end
        self.batteryStart = sortedRecords.first?.battery
        self.batteryEnd = sortedRecords.last?.battery
    }
    
    // MARK: - Distance Calculation (Haversine formula)
    
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
    
    // MARK: - Formatted Values
    
    var formattedDuration: String {
        let hours = Int(flightDuration) / 3600
        let minutes = (Int(flightDuration) % 3600) / 60
        let seconds = Int(flightDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedMaxAltitude: String {
        maxAltitude.map { String(format: "%.1f m", $0) } ?? "—"
    }
    
    var formattedMaxSpeed: String {
        maxSpeed.map { String(format: "%.1f m/s", $0) } ?? "—"
    }
    
    var formattedAvgSpeed: String {
        avgSpeed.map { String(format: "%.1f m/s", $0) } ?? "—"
    }
    
    var formattedTotalDistance: String {
        totalDistance.map { String(format: "%.1f m", $0) } ?? "—"
    }
    
    var formattedBatteryRange: String {
        if let start = batteryStart, let end = batteryEnd {
            return "\(start)% → \(end)%"
        } else if let start = batteryStart {
            return "\(start)% → —"
        } else {
            return "—"
        }
    }
}
