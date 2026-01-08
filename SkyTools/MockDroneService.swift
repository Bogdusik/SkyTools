//
//  MockDroneService.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import Foundation
import CoreLocation
import Combine

/// Mock drone service for demonstration without real drone
@MainActor
final class MockDroneService: ObservableObject {
    
    static let shared = MockDroneService()
    
    // Configuration
    private let updateInterval: TimeInterval = 0.5 // Update every 0.5 seconds
    private var timer: Timer?
    private var isRunning = false
    
    // Mock state
    private var flightStartTime: Date?
    private var baseLocation: CLLocation
    private var currentHeading: Double = 0.0
    private var currentSpeed: Double = 0.0
    private var currentAltitude: Double = 0.0
    private var batteryLevel: Int = 100
    
    // Callbacks
    var onTelemetryUpdate: ((TelemetryRecord) -> Void)?
    
    private init() {
        // Initialize with a default location (can be changed)
        self.baseLocation = CLLocation(latitude: 55.8642, longitude: -4.2518) // Glasgow, UK
    }
    
    // MARK: - Control
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        flightStartTime = Date()
        
        // Initialize mock state
        currentHeading = Double.random(in: 0...360)
        currentSpeed = 0.0
        currentAltitude = 0.0
        batteryLevel = 100
        
        print("🤖 MockDroneService: Started mock drone simulation")
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMockTelemetry()
            }
        }
    }
    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🤖 MockDroneService: Stopped mock drone simulation")
    }
    
    // MARK: - Mock Telemetry Generation
    
    private func updateMockTelemetry() {
        // Simulate flight progression
        let elapsed = Date().timeIntervalSince(flightStartTime ?? Date())
        
        // Gradually increase altitude (up to 50m)
        if currentAltitude < 50.0 {
            currentAltitude = min(50.0, Double(elapsed) * 2.0) // 2 m/s climb rate
        }
        
        // Simulate speed changes (0-15 m/s)
        if elapsed > 5.0 {
            currentSpeed = 5.0 + sin(elapsed * 0.1) * 5.0 + Double.random(in: -1...1)
            currentSpeed = max(0, min(15, currentSpeed))
        }
        
        // Simulate heading changes
        currentHeading += Double.random(in: -5...5)
        if currentHeading < 0 { currentHeading += 360 }
        if currentHeading >= 360 { currentHeading -= 360 }
        
        // Simulate battery drain (1% per 30 seconds)
        if elapsed.truncatingRemainder(dividingBy: 30) < updateInterval {
            batteryLevel = max(20, batteryLevel - 1)
        }
        
        // Calculate new position based on speed and heading
        let distance = currentSpeed * updateInterval // meters
        let newLocation = calculateNewLocation(
            from: baseLocation,
            distance: distance,
            heading: currentHeading
        )
        baseLocation = newLocation // Update base location for next iteration
        
        // Generate telemetry record
        let record = TelemetryRecord(
            sessionId: TelemetryLogger.shared.currentSessionId ?? UUID(),
            timestamp: Date(),
            battery: batteryLevel,
            satellites: Int.random(in: 8...15),
            altitude: currentAltitude,
            speed: currentSpeed,
            latitude: newLocation.coordinate.latitude,
            longitude: newLocation.coordinate.longitude,
            heading: currentHeading,
            gpsSignalLevel: Int.random(in: 3...5),
            rcSignalLevel: Int.random(in: 80...100),
            homeLatitude: baseLocation.coordinate.latitude,
            homeLongitude: baseLocation.coordinate.longitude
        )
        
        onTelemetryUpdate?(record)
    }
    
    private func calculateNewLocation(from location: CLLocation, distance: Double, heading: Double) -> CLLocation {
        let R = 6371000.0 // Earth radius in meters
        let lat1 = location.coordinate.latitude * .pi / 180.0
        let lon1 = location.coordinate.longitude * .pi / 180.0
        let bearing = heading * .pi / 180.0
        
        let lat2 = asin(sin(lat1) * cos(distance / R) +
                       cos(lat1) * sin(distance / R) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distance / R) * cos(lat1),
                               cos(distance / R) - sin(lat1) * sin(lat2))
        
        return CLLocation(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
}
