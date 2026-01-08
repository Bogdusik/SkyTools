//
//  SettingsView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logging") {
                    Picker("Frequency", selection: $settings.loggingFrequency) {
                        ForEach(AppSettings.LoggingFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    
                    Toggle("Auto Start Session", isOn: $settings.autoStartSession)
                    Toggle("Auto End Session", isOn: $settings.autoEndSession)
                }
                
                Section("Units") {
                    Picker("Speed", selection: $settings.speedUnit) {
                        ForEach(AppSettings.SpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    
                    Picker("Altitude", selection: $settings.altitudeUnit) {
                        ForEach(AppSettings.AltitudeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
                
                Section("Features") {
                    Toggle("Event Markers", isOn: $settings.eventMarkersEnabled)
                }
                
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Data")
                            .font(.headline)
                        Text("SkyTools only reads drone location from DJI SDK. Your device location is never accessed or transmitted. All flight data is stored locally on your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(appBuild)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    SettingsView()
}
