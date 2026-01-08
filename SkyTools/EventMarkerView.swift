//
//  EventMarkerView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct EventMarkerView: View {
    @EnvironmentObject var drone: DroneStore
    @ObservedObject private var eventManager = EventManager.shared
    @State private var showingEventSheet = false
    @State private var selectedEventType: FlightEvent.EventType = .interesting
    @State private var eventNote: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Mark Event")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Quick action buttons
            HStack(spacing: 8) {
                EventButton(
                    type: .interesting,
                    icon: "camera.fill",
                    color: .blue
                ) {
                    markEvent(type: .interesting)
                }
                
                EventButton(
                    type: .problem,
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    markEvent(type: .problem)
                }
                
                EventButton(
                    type: .wind,
                    icon: "wind",
                    color: .orange
                ) {
                    markEvent(type: .wind)
                }
                
                EventButton(
                    type: .custom,
                    icon: "tag.fill",
                    color: .purple
                ) {
                    showingEventSheet = true
                }
            }
            
            // Recent events
            if !recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(recentEvents.prefix(3)) { event in
                        HStack {
                            Image(systemName: event.type.icon)
                                .foregroundColor(eventColor(event.type))
                            Text(event.type.rawValue)
                                .font(.caption)
                            if let note = event.note {
                                Text("• \(note)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingEventSheet) {
            CustomEventSheet(
                eventType: $selectedEventType,
                note: $eventNote,
                onSave: {
                    markEvent(type: selectedEventType, note: eventNote.isEmpty ? nil : eventNote)
                    eventNote = ""
                    showingEventSheet = false
                },
                onCancel: {
                    eventNote = ""
                    showingEventSheet = false
                }
            )
        }
        .onAppear {
            EventManager.shared.loadEvents()
        }
    }
    
    private var recentEvents: [FlightEvent] {
        guard let sessionId = TelemetryLogger.shared.currentSessionId else { return [] }
        return eventManager.eventsForSession(sessionId)
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func markEvent(type: FlightEvent.EventType, note: String? = nil) {
        guard let sessionId = TelemetryLogger.shared.currentSessionId else { return }
        
        let event = eventManager.addEvent(
            sessionId: sessionId,
            type: type,
            note: note,
            latitude: drone.latitude,
            longitude: drone.longitude,
            altitude: drone.altitudeMeters
        )
        
        print("📌 Marked event: \(type.rawValue) at \(event.timestamp)")
    }
    
    private func eventColor(_ type: FlightEvent.EventType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct EventButton: View {
    let type: FlightEvent.EventType
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(type.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
        }
    }
}

struct CustomEventSheet: View {
    @Binding var eventType: FlightEvent.EventType
    @Binding var note: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Event Type", selection: $eventType) {
                    ForEach(FlightEvent.EventType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                Section("Note (optional)") {
                    TextField("Add a note...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Mark Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}
