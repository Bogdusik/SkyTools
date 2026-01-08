//
//  SystemView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct SystemView: View {
    @EnvironmentObject var drone: DroneStore
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionView(title: "SDK Info") {
                        row("Registration", drone.sdkRegistrationState.rawValue, color: registrationColor(drone.sdkRegistrationState))
                        row("Connection", drone.isConnected ? "Connected" : "Disconnected", color: drone.isConnected ? .green : .red)
                        row("Product Model", drone.modelName)
                        row("Flight Controller", drone.flightControllerAvailable ? "Available" : "Not Available", color: drone.flightControllerAvailable ? .green : .orange)
                        row("Battery", drone.batteryAvailable ? "Available" : "Not Available", color: drone.batteryAvailable ? .green : .orange)
                    }
                    
                    if let error = drone.sdkError {
                        SectionView(title: "SDK Error") {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    if let lastError = drone.lastError, let errorTime = drone.lastErrorTime {
                        SectionView(title: "Last Error") {
                            row("Error", lastError, color: .red)
                            row("Time", errorTimeFormatter.string(from: errorTime), color: .secondary)
                        }
                    }
                    
                    SectionView(title: "Device Info") {
                        row("Device", UIDevice.current.model)
                        row("OS Version", UIDevice.current.systemVersion)
                        row("App Version", appVersion)
                    }
                    
                    SectionView(title: "Session Info") {
                        row("Telemetry Entries", "\(drone.telemetryLog.count)")
                        row("Memory Usage", memoryUsageString)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("System")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown"
    }
    
    private var memoryUsageString: String {
        // Simplified memory usage - can be enhanced later
        return "N/A"
    }
    
    private func row(_ title: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(title + ":")
                .frame(width: 120, alignment: .leading)
            Text(value)
                .bold()
                .foregroundColor(color)
            Spacer()
        }
        .font(.system(size: 14))
    }
    
    private func registrationColor(_ state: DroneStore.SDKRegistrationState) -> Color {
        switch state {
        case .registered: return .green
        case .registering: return .orange
        case .failed: return .red
        case .unknown: return .secondary
        }
    }
    
    private var errorTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    SystemView()
        .environmentObject(DroneStore.shared)
}
