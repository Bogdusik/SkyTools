//
//  EventManager.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import Combine

/// Manages flight event markers
@MainActor
final class EventManager: ObservableObject {
    
    static let shared = EventManager()
    
    @Published private(set) var events: [FlightEvent] = []
    
    private init() {}
    
    // MARK: - Event Management
    
    func addEvent(
        sessionId: UUID,
        type: FlightEvent.EventType,
        note: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil
    ) -> FlightEvent {
        let event = FlightEvent(
            sessionId: sessionId,
            timestamp: Date(),
            type: type,
            note: note,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude
        )
        
        events.append(event)
        saveEvents()
        
        print("📌 EventManager: Added \(type.rawValue) event")
        return event
    }
    
    func eventsForSession(_ sessionId: UUID) -> [FlightEvent] {
        events.filter { $0.sessionId == sessionId }
    }
    
    func removeEvent(_ event: FlightEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }
    
    func clearSession(_ sessionId: UUID) {
        events.removeAll { $0.sessionId == sessionId }
        saveEvents()
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        // Save to UserDefaults for simplicity (can be moved to file later)
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "FlightEvents")
        }
    }
    
    func loadEvents() {
        // Load from UserDefaults (legacy)
        if let data = UserDefaults.standard.data(forKey: "FlightEvents"),
           let decoded = try? JSONDecoder().decode([FlightEvent].self, from: data) {
            events = decoded
        }
    }
    
    /// Load events for a session from disk (NEW: Point 1)
    func loadEventsForSession(_ sessionId: UUID) {
        if let sessionEvents = SessionManager.shared.loadEvents(for: sessionId) {
            // Merge with existing events (avoid duplicates)
            for event in sessionEvents {
                if !events.contains(where: { $0.id == event.id }) {
                    events.append(event)
                }
            }
            saveEvents() // Save merged events
        }
    }
}
