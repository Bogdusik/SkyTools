//
//  TelemetryLogger.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import Combine

/// Telemetry logging service
/// Manages flight session logging with automatic persistence to disk
/// - Sessions are automatically saved when ended
/// - Supports querying by session ID
/// - Provides flight summary generation
/// - Live buffer is capped at 1000 records; the saved session keeps every record
///
/// PRIVACY: All data is stored locally on device. No data is transmitted to external servers.
@MainActor
final class TelemetryLogger: ObservableObject {
    
    static let shared = TelemetryLogger()
    
    // Current session
    @Published private(set) var currentSessionId: UUID?
    @Published private(set) var records: [TelemetryRecord] = []
    
    // Configuration
    /// Cap for the live buffer shown in the UI. Saved sessions are not capped.
    let liveRecordLimit = 1000
    private var currentSessionRecords: [TelemetryRecord] = []
    private var currentSessionRecordsId: UUID?
    private(set) var sessionStartTime: Date?
    
    private init() {}
    
    // MARK: - Session Management
    
    func startSession() -> UUID {
        let sessionId = UUID()
        currentSessionId = sessionId
        sessionStartTime = Date()
        records.removeAll()
        currentSessionRecords.removeAll()
        currentSessionRecordsId = sessionId
        print("📊 TelemetryLogger: Started session \(sessionId.uuidString.prefix(8))")
        return sessionId
    }
    
    func endSession() {
        if let sessionId = currentSessionId {
            let sessionRecords = recordsForSession(sessionId)
            let summary = generateSummary(for: sessionId)
            
            // Get events for this session (NEW: Point 1)
            let events = EventManager.shared.eventsForSession(sessionId)
            
            // Save to disk (including events)
            SessionManager.shared.saveSession(
                sessionId: sessionId,
                records: sessionRecords,
                summary: summary,
                events: events
            )
            
            print("📊 TelemetryLogger: Ended session \(sessionId.uuidString.prefix(8)) with \(sessionRecords.count) records and \(events.count) events")
        }
        currentSessionId = nil
        sessionStartTime = nil
    }
    
    // MARK: - Logging
    
    func log(_ record: TelemetryRecord) {
        guard let sessionId = currentSessionId, record.sessionId == sessionId else {
            // Auto-start session if not started
            let newSessionId = startSession()
            let recordWithSession = TelemetryRecord(
                id: record.id,
                sessionId: newSessionId,
                timestamp: record.timestamp,
                battery: record.battery,
                satellites: record.satellites,
                altitude: record.altitude,
                speed: record.speed,
                latitude: record.latitude,
                longitude: record.longitude,
                heading: record.heading,
                gpsSignalLevel: record.gpsSignalLevel,
                rcSignalLevel: record.rcSignalLevel,
                homeLatitude: record.homeLatitude,
                homeLongitude: record.homeLongitude
            )
            log(recordWithSession)
            return
        }
        
        records.append(record)
        currentSessionRecords.append(record)
        
        // Keep only the last liveRecordLimit in the published buffer
        if records.count > liveRecordLimit {
            records.removeFirst(records.count - liveRecordLimit)
        }
    }
    
    // MARK: - Query
    
    func recordsForSession(_ sessionId: UUID) -> [TelemetryRecord] {
        if sessionId == currentSessionRecordsId {
            return currentSessionRecords
        }
        return records.filter { $0.sessionId == sessionId }
    }
    
    func allSessions() -> [UUID] {
        Array(Set(records.map { $0.sessionId }))
    }
    
    // MARK: - File Persistence
    
    /// Export current session to JSON data
    func exportToJSON(for sessionId: UUID? = nil) -> Data? {
        let targetSessionId = sessionId ?? currentSessionId
        guard let sessionId = targetSessionId else { return nil }
        
        let sessionRecords = recordsForSession(sessionId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(sessionRecords)
    }
    
    /// Get all saved session IDs from disk
    func loadSavedSessions() -> [UUID] {
        return SessionManager.shared.loadAllSessionIds()
    }
    
    /// Load records for a saved session
    func loadSavedRecords(for sessionId: UUID) -> [TelemetryRecord]? {
        return SessionManager.shared.loadRecords(for: sessionId)
    }
    
    /// Load summary for a saved session
    func loadSavedSummary(for sessionId: UUID) -> FlightSummary? {
        return SessionManager.shared.loadSummary(for: sessionId)
    }
    
    /// Clear all records (for testing/debugging)
    func clearAll() {
        records.removeAll()
        endSession()
    }
    
    // MARK: - Flight Summary
    
    /// Generate flight summary for current or specified session
    func generateSummary(for sessionId: UUID? = nil) -> FlightSummary? {
        let targetSessionId = sessionId ?? currentSessionId
        guard let sessionId = targetSessionId else { return nil }
        
        let sessionRecords = recordsForSession(sessionId)
        guard !sessionRecords.isEmpty else { return nil }
        
        let sortedRecords = sessionRecords.sorted { $0.timestamp < $1.timestamp }
        let startTime = sortedRecords.first?.timestamp ?? Date()
        let endTime = sortedRecords.last?.timestamp
        
        return FlightSummary(
            sessionId: sessionId,
            startTime: startTime,
            endTime: endTime,
            records: sessionRecords
        )
    }
    
    /// Get summary for current active session
    func currentSessionSummary() -> FlightSummary? {
        guard let sessionId = currentSessionId else { return nil }
        return generateSummary(for: sessionId)
    }
}
