//
//  ExportManager.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation

/// Manages export of flight data to various formats
/// PRIVACY: Only exports locally stored drone telemetry data.
/// No user location or personal data is included in exports.
@MainActor
final class ExportManager {
    
    static let shared = ExportManager()
    
    private init() {}
    
    // MARK: - CSV Export
    
    func exportToCSV(records: [TelemetryRecord]) -> Data? {
        // Validation (NEW: Point 4)
        guard !records.isEmpty else {
            print("⚠️ ExportManager: Cannot export CSV - no records provided")
            return nil
        }
        
        // Validate that at least some records have valid data
        let validRecords = records.filter { record in
            record.latitude != nil || record.longitude != nil || record.battery != nil
        }
        
        guard !validRecords.isEmpty else {
            print("⚠️ ExportManager: Cannot export CSV - no valid records found")
            return nil
        }
        
        var csv = "Timestamp,Battery (%),Satellites,Altitude (m),Speed (m/s),Latitude,Longitude,Heading (°),GPS Signal,RC Signal (%),Home Lat,Home Lon\n"
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for record in validRecords.sorted(by: { $0.timestamp < $1.timestamp }) {
            let timestamp = dateFormatter.string(from: record.timestamp)
            let battery = record.battery.map { "\($0)" } ?? ""
            let satellites = record.satellites.map { "\($0)" } ?? ""
            let altitude = record.altitude.map { String(format: "%.2f", $0) } ?? ""
            let speed = record.speed.map { String(format: "%.2f", $0) } ?? ""
            let lat = record.latitude.map { String(format: "%.8f", $0) } ?? ""
            let lon = record.longitude.map { String(format: "%.8f", $0) } ?? ""
            let heading = record.heading.map { String(format: "%.2f", $0) } ?? ""
            let gpsSignal = record.gpsSignalLevel.map { "\($0)" } ?? ""
            let rcSignal = record.rcSignalLevel.map { "\($0)" } ?? ""
            let homeLat = record.homeLatitude.map { String(format: "%.8f", $0) } ?? ""
            let homeLon = record.homeLongitude.map { String(format: "%.8f", $0) } ?? ""
            
            csv += "\(timestamp),\(battery),\(satellites),\(altitude),\(speed),\(lat),\(lon),\(heading),\(gpsSignal),\(rcSignal),\(homeLat),\(homeLon)\n"
        }
        
        return csv.data(using: .utf8)
    }
    
    // MARK: - GPX Export
    
    func exportToGPX(records: [TelemetryRecord], sessionId: UUID) -> Data? {
        // Validation (NEW: Point 4)
        guard !records.isEmpty else {
            print("⚠️ ExportManager: Cannot export GPX - no records provided")
            return nil
        }
        
        // GPX requires at least one record with valid coordinates
        let recordsWithCoordinates = records.filter { record in
            record.latitude != nil && record.longitude != nil
        }
        
        guard !recordsWithCoordinates.isEmpty else {
            print("⚠️ ExportManager: Cannot export GPX - no records with valid coordinates")
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        gpx += "<gpx version=\"1.1\" creator=\"SkyTools\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        gpx += "  <metadata>\n"
        gpx += "    <name>Flight Session \(sessionId.uuidString.prefix(8))</name>\n"
        if let firstRecord = recordsWithCoordinates.first {
            gpx += "    <time>\(dateFormatter.string(from: firstRecord.timestamp))</time>\n"
        }
        gpx += "  </metadata>\n"
        gpx += "  <trk>\n"
        gpx += "    <name>Flight Track</name>\n"
        gpx += "    <trkseg>\n"
        
        for record in recordsWithCoordinates.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let lat = record.latitude, let lon = record.longitude else { continue }
            
            gpx += "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">\n"
            if let altitude = record.altitude {
                gpx += "        <ele>\(altitude)</ele>\n"
            }
            gpx += "        <time>\(dateFormatter.string(from: record.timestamp))</time>\n"
            
            // Add extensions with additional telemetry
            gpx += "        <extensions>\n"
            if let battery = record.battery {
                gpx += "          <battery>\(battery)</battery>\n"
            }
            if let speed = record.speed {
                gpx += "          <speed>\(speed)</speed>\n"
            }
            if let heading = record.heading {
                gpx += "          <heading>\(heading)</heading>\n"
            }
            if let satellites = record.satellites {
                gpx += "          <satellites>\(satellites)</satellites>\n"
            }
            gpx += "        </extensions>\n"
            
            gpx += "      </trkpt>\n"
        }
        
        gpx += "    </trkseg>\n"
        gpx += "  </trk>\n"
        
        // Add waypoints for home point
        if let firstRecord = recordsWithCoordinates.first,
           let homeLat = firstRecord.homeLatitude,
           let homeLon = firstRecord.homeLongitude {
            gpx += "  <wpt lat=\"\(homeLat)\" lon=\"\(homeLon)\">\n"
            gpx += "    <name>Home Point</name>\n"
            gpx += "    <sym>Flag, Red</sym>\n"
            gpx += "  </wpt>\n"
        }
        
        gpx += "</gpx>\n"
        
        return gpx.data(using: .utf8)
    }
}
