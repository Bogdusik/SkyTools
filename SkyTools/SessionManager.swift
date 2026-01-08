//
//  SessionManager.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import Combine

/// Manages session persistence on disk
@MainActor
final class SessionManager: ObservableObject {
    
    static let shared = SessionManager()
    
    private let fileManager = FileManager.default
    private var sessionsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Sessions", isDirectory: true)
    }
    
    // Error tracking
    @Published var lastSaveError: String? = nil
    @Published var lastDeleteError: String? = nil
    
    private init() {
        ensureSessionsDirectoryExists()
    }
    
    // MARK: - Directory Setup
    
    private func ensureSessionsDirectoryExists() {
        if !fileManager.fileExists(atPath: sessionsDirectory.path) {
            do {
                try fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
                print("📁 SessionManager: Created Sessions directory")
            } catch {
                let errorMsg = "Failed to create Sessions directory: \(error.localizedDescription)"
                lastSaveError = errorMsg
                print("❌ SessionManager: \(errorMsg)")
            }
        }
    }
    
    // MARK: - Save Session
    
    /// Save session data to disk (including events)
    func saveSession(sessionId: UUID, records: [TelemetryRecord], summary: FlightSummary?, events: [FlightEvent] = []) {
        lastSaveError = nil
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        
        // Create session directory
        do {
            if !fileManager.fileExists(atPath: sessionDir.path) {
                try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            }
        } catch {
            let errorMsg = "Failed to create session directory: \(error.localizedDescription)"
            lastSaveError = errorMsg
            print("❌ SessionManager: \(errorMsg)")
            return
        }
        
        // Save records
        let recordsFile = sessionDir.appendingPathComponent("\(sessionId.uuidString).json")
        if let recordsData = encodeRecords(records) {
            do {
                try recordsData.write(to: recordsFile, options: .atomic)
                print("💾 SessionManager: Saved \(records.count) records to \(recordsFile.lastPathComponent)")
            } catch {
                let errorMsg = "Failed to save records: \(error.localizedDescription)"
                lastSaveError = errorMsg
                print("❌ SessionManager: \(errorMsg)")
            }
        } else {
            let errorMsg = "Failed to encode records"
            lastSaveError = errorMsg
            print("❌ SessionManager: \(errorMsg)")
        }
        
        // Save summary
        if let summary = summary {
            let summaryFile = sessionDir.appendingPathComponent("\(sessionId.uuidString).summary.json")
            if let summaryData = encodeSummary(summary) {
                do {
                    try summaryData.write(to: summaryFile, options: .atomic)
                    print("💾 SessionManager: Saved summary to \(summaryFile.lastPathComponent)")
                } catch {
                    let errorMsg = "Failed to save summary: \(error.localizedDescription)"
                    lastSaveError = errorMsg
                    print("❌ SessionManager: \(errorMsg)")
                }
            } else {
                let errorMsg = "Failed to encode summary"
                lastSaveError = errorMsg
                print("❌ SessionManager: \(errorMsg)")
            }
        }
        
        // Save events (NEW: Point 1)
        if !events.isEmpty {
            let eventsFile = sessionDir.appendingPathComponent("\(sessionId.uuidString).events.json")
            if let eventsData = encodeEvents(events) {
                do {
                    try eventsData.write(to: eventsFile, options: .atomic)
                    print("💾 SessionManager: Saved \(events.count) events to \(eventsFile.lastPathComponent)")
                } catch {
                    let errorMsg = "Failed to save events: \(error.localizedDescription)"
                    lastSaveError = errorMsg
                    print("❌ SessionManager: \(errorMsg)")
                }
            } else {
                let errorMsg = "Failed to encode events"
                lastSaveError = errorMsg
                print("❌ SessionManager: \(errorMsg)")
            }
        }
    }
    
    // MARK: - Load Sessions
    
    /// Load all saved session IDs
    func loadAllSessionIds() -> [UUID] {
        guard let contents = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.creationDateKey], options: []) else {
            return []
        }
        
        return contents
            .filter { $0.hasDirectoryPath }
            .compactMap { UUID(uuidString: $0.lastPathComponent) }
            .sorted { session1, session2 in
                // Sort by creation date (newest first)
                let date1 = creationDate(for: session1) ?? Date.distantPast
                let date2 = creationDate(for: session2) ?? Date.distantPast
                return date1 > date2
            }
    }
    
    /// Load records for a session
    func loadRecords(for sessionId: UUID) -> [TelemetryRecord]? {
        let recordsFile = sessionsDirectory
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).json")
        
        guard let data = try? Data(contentsOf: recordsFile) else {
            return nil
        }
        
        return decodeRecords(data)
    }
    
    /// Load summary for a session
    func loadSummary(for sessionId: UUID) -> FlightSummary? {
        let summaryFile = sessionsDirectory
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).summary.json")
        
        guard let data = try? Data(contentsOf: summaryFile) else {
            return nil
        }
        
        return decodeSummary(data)
    }
    
    /// Load events for a session (NEW: Point 1)
    func loadEvents(for sessionId: UUID) -> [FlightEvent]? {
        let eventsFile = sessionsDirectory
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).events.json")
        
        guard let data = try? Data(contentsOf: eventsFile) else {
            return nil
        }
        
        return decodeEvents(data)
    }
    
    /// Get creation date for a session
    func creationDate(for sessionId: UUID) -> Date? {
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        guard let attributes = try? fileManager.attributesOfItem(atPath: sessionDir.path),
              let creationDate = attributes[.creationDate] as? Date else {
            return nil
        }
        return creationDate
    }
    
    // MARK: - Delete Session (NEW: Point 2)
    
    /// Delete a session and all its data (records, summary, events)
    func deleteSession(_ sessionId: UUID) -> Bool {
        lastDeleteError = nil
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        
        guard fileManager.fileExists(atPath: sessionDir.path) else {
            lastDeleteError = "Session directory does not exist"
            return false
        }
        
        do {
            try fileManager.removeItem(at: sessionDir)
            print("🗑️ SessionManager: Deleted session \(sessionId.uuidString.prefix(8))")
            
            // Also clear events from EventManager (NEW: Point 5)
            EventManager.shared.clearSession(sessionId)
            
            return true
        } catch {
            let errorMsg = "Failed to delete session: \(error.localizedDescription)"
            lastDeleteError = errorMsg
            print("❌ SessionManager: \(errorMsg)")
            return false
        }
    }
    
    // MARK: - Export
    
    /// Get file URL for exporting session
    func exportFileURL(for sessionId: UUID) -> URL? {
        let recordsFile = sessionsDirectory
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).json")
        
        guard fileManager.fileExists(atPath: recordsFile.path) else {
            return nil
        }
        
        return recordsFile
    }
    
    // MARK: - Encoding/Decoding
    
    private func encodeRecords(_ records: [TelemetryRecord]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(records)
    }
    
    private func decodeRecords(_ data: Data) -> [TelemetryRecord]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([TelemetryRecord].self, from: data)
    }
    
    private func encodeSummary(_ summary: FlightSummary) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // FlightSummary needs to be Codable - we'll create a simple struct for encoding
        struct SummaryCodable: Codable {
            let id: String
            let sessionId: String
            let startTime: Date
            let endTime: Date?
            let maxAltitude: Double?
            let maxSpeed: Double?
            let avgSpeed: Double?
            let flightDuration: TimeInterval
            let totalDistance: Double?
            let batteryStart: Int?
            let batteryEnd: Int?
        }
        
        let codable = SummaryCodable(
            id: summary.id.uuidString,
            sessionId: summary.sessionId.uuidString,
            startTime: summary.startTime,
            endTime: summary.endTime,
            maxAltitude: summary.maxAltitude,
            maxSpeed: summary.maxSpeed,
            avgSpeed: summary.avgSpeed,
            flightDuration: summary.flightDuration,
            totalDistance: summary.totalDistance,
            batteryStart: summary.batteryStart,
            batteryEnd: summary.batteryEnd
        )
        
        return try? encoder.encode(codable)
    }
    
    private func decodeSummary(_ data: Data) -> FlightSummary? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct SummaryCodable: Codable {
            let id: String
            let sessionId: String
            let startTime: Date
            let endTime: Date?
            let maxAltitude: Double?
            let maxSpeed: Double?
            let avgSpeed: Double?
            let flightDuration: TimeInterval
            let totalDistance: Double?
            let batteryStart: Int?
            let batteryEnd: Int?
        }
        
        guard let codable = try? decoder.decode(SummaryCodable.self, from: data),
              let id = UUID(uuidString: codable.id),
              let sessionId = UUID(uuidString: codable.sessionId) else {
            return nil
        }
        
        // We need records to create FlightSummary, so load them
        guard let records = loadRecords(for: sessionId) else {
            return nil
        }
        
        return FlightSummary(
            id: id,
            sessionId: sessionId,
            startTime: codable.startTime,
            endTime: codable.endTime,
            records: records
        )
    }
    
    // MARK: - Events Encoding/Decoding (NEW: Point 1)
    
    private func encodeEvents(_ events: [FlightEvent]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(events)
    }
    
    private func decodeEvents(_ data: Data) -> [FlightEvent]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([FlightEvent].self, from: data)
    }
}
