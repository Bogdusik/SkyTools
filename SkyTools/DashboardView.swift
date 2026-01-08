//
//  DashboardView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var drone: DroneStore
    @State private var flightSummary: FlightSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Mock Control (only in mock mode)
                    if USE_MOCK_DRONE {
                        MockControlView()
                        Divider()
                    }
                    
                    // Connection Status
                    StatusSection()
                    
                    Divider()
                    
                    // KPI Cards (if we have summary data)
                    if let summary = flightSummary {
                        KPICardsSection(summary: summary)
                        Divider()
                    }
                    
                    // Signal Quality Indicators
                    SignalQualitySection()
                    
                    Divider()
                    
                    // Flight Summary (Analytics)
                    if let summary = flightSummary {
                        FlightSummarySection(summary: summary)
                        Divider()
                    }
                    
                    // Live Telemetry
                    if drone.isConnected {
                        TelemetrySection()
                    } else {
                        EmptyTelemetryView()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                updateSummary()
            }
            .onChange(of: drone.telemetryLog.count) { _ in
                updateSummary()
            }
        }
    }
    
    private func updateSummary() {
        flightSummary = TelemetryLogger.shared.currentSessionSummary()
    }
}

// MARK: - KPI Cards Section

struct KPICardsSection: View {
    let summary: FlightSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flight Metrics")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                KPICard(
                    icon: "arrow.up",
                    title: "Max Altitude",
                    value: summary.formattedMaxAltitude,
                    color: .blue
                )
                
                KPICard(
                    icon: "speedometer",
                    title: "Max Speed",
                    value: summary.formattedMaxSpeed,
                    color: .orange
                )
                
                KPICard(
                    icon: "location",
                    title: "Distance",
                    value: summary.formattedTotalDistance,
                    color: .green
                )
                
                KPICard(
                    icon: "battery.100",
                    title: "Battery Drop",
                    value: summary.formattedBatteryRange,
                    color: batteryDropColor(summary)
                )
            }
        }
    }
    
    private func batteryDropColor(_ summary: FlightSummary) -> Color {
        guard let start = summary.batteryStart, let end = summary.batteryEnd else {
            return .gray
        }
        let drop = start - end
        if drop > 30 {
            return .red
        } else if drop > 15 {
            return .orange
        } else {
            return .green
        }
    }
}

struct KPICard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 32, height: 32)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Signal Quality Section

struct SignalQualitySection: View {
    @EnvironmentObject var drone: DroneStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal Quality")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                SignalQualityIndicator(
                    title: "GPS",
                    level: drone.gpsSignalLevel,
                    maxLevel: 5,
                    color: .blue
                )
                
                SignalQualityIndicator(
                    title: "RC",
                    level: drone.rcSignalLevel,
                    maxLevel: 100,
                    color: .green
                )
            }
        }
    }
}

struct SignalQualityIndicator: View {
    let title: String
    let level: Int?
    let maxLevel: Int
    let color: Color
    
    private var normalizedLevel: Double {
        guard let level = level, level >= 0 else { return 0 }
        return min(Double(level) / Double(maxLevel), 1.0)
    }
    
    private var qualityColor: Color {
        if normalizedLevel >= 0.8 {
            return .green
        } else if normalizedLevel >= 0.5 {
            return .orange
        } else if normalizedLevel > 0 {
            return .red
        } else {
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Spacer()
                if let level = level {
                    Text("\(level)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(qualityColor)
                        .frame(width: geometry.size.width * normalizedLevel, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Status Section
struct StatusSection: View {
    @EnvironmentObject var drone: DroneStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Status:")
                Text(drone.isConnected ? "Connected" : "Disconnected")
                    .bold()
                    .foregroundColor(drone.isConnected ? .green : .red)
            }
            
            HStack {
                Text("Model:")
                Text(drone.modelName).bold()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Flight Summary Section
struct FlightSummarySection: View {
    let summary: FlightSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flight Summary")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                summaryRow("Duration", summary.formattedDuration)
                summaryRow("Max Altitude", summary.formattedMaxAltitude)
                summaryRow("Max Speed", summary.formattedMaxSpeed)
                summaryRow("Avg Speed", summary.formattedAvgSpeed)
                summaryRow("Distance", summary.formattedTotalDistance)
                summaryRow("Battery", summary.formattedBatteryRange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title + ":")
                .frame(width: 100, alignment: .leading)
            Text(value)
                .bold()
            Spacer()
        }
        .font(.system(size: 14))
    }
}

// MARK: - Telemetry Section
struct TelemetrySection: View {
    @EnvironmentObject var drone: DroneStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Telemetry")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                row("Battery", drone.formattedBattery)
                row("Satellites", drone.satellites.map { "\($0)" } ?? "—")
                row("GPS Signal", drone.formattedGPSSignal)
                row("RC Signal", drone.formattedRCSignal)
                row("Altitude", drone.formattedAltitude)
                row("Speed", drone.formattedSpeed)
                row("Heading", drone.formattedHeading)
                let coords = drone.formattedCoordinates
                row("Lat", coords.lat)
                row("Lon", coords.lon)
                let homeCoords = drone.formattedHomeCoordinates
                row("Home Lat", homeCoords.lat)
                row("Home Lon", homeCoords.lon)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title + ":")
                .frame(width: 90, alignment: .leading)
            Text(value).bold()
            Spacer()
        }
        .font(.system(size: 15))
    }
}

// MARK: - Empty Telemetry View

struct EmptyTelemetryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Telemetry")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No Connection")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Connect your DJI drone to start receiving telemetry data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DroneStore.shared)
}
