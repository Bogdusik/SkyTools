import Foundation
import Combine
import CoreLocation
import DJISDK

/// Central state manager for drone connection and telemetry
/// Handles DJI SDK delegates, telemetry logging, and data normalization
/// Uses fixed-rate logging timer to prevent excessive writes
///
/// PRIVACY & SECURITY:
/// - Only reads telemetry data from DJI SDK (drone position, battery, etc.)
/// - Does NOT access user's device location via CLLocationManager
/// - Does NOT transmit any data to DJI or third-party servers
/// - All data is stored locally on device only
/// - User location is never accessed or shared
@MainActor
final class DroneStore: NSObject, ObservableObject {

    static let shared = DroneStore()

    // Connection
    @Published var isConnected: Bool = false
    @Published var modelName: String = "—"
    
    // SDK State
    @Published var sdkRegistrationState: SDKRegistrationState = .unknown
    @Published var sdkError: String? = nil
    @Published var flightControllerAvailable: Bool = false
    @Published var batteryAvailable: Bool = false
    @Published var lastError: String? = nil
    @Published var lastErrorTime: Date? = nil

    // Telemetry (Stage 2)
    @Published var batteryPercent: Int? = nil
    @Published var satellites: Int? = nil
    @Published var altitudeMeters: Double? = nil
    @Published var speedMS: Double? = nil
    @Published var latitude: Double? = nil
    @Published var longitude: Double? = nil
    
    // Extended telemetry
    @Published var gpsSignalLevel: Int? = nil
    @Published var rcSignalLevel: Int? = nil
    @Published var homeLatitude: Double? = nil
    @Published var homeLongitude: Double? = nil
    @Published var heading: Double? = nil
    
    // Telemetry log (using TelemetryLogger)
    @Published var telemetryLog: [TelemetryRecord] = []
    private let logger = TelemetryLogger.shared
    private var currentSessionId: UUID?
    private var loggerCancellable: AnyCancellable?
    
    // Telemetry logging rate control
    private var telemetryTimer: Timer?
    private var pendingTelemetry: TelemetryRecord?
    private let settings = AppSettings.shared
    
    private var telemetryLoggingRate: TimeInterval {
        settings.loggingFrequency.interval
    }
    
    override init() {
        super.init()
        // Subscribe to logger changes
        loggerCancellable = logger.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTelemetryLog()
                }
            }
        
        // Restart timer if logging frequency changes
        settings.$loggingFrequency
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    if self?.isConnected == true {
                        self?.stopTelemetryLoggingTimer()
                        self?.startTelemetryLoggingTimer()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()

    private weak var aircraft: DJIAircraft?
    private weak var flightController: DJIFlightController?
    private weak var battery: DJIBattery?
    private weak var remoteController: DJIRemoteController?
    
    // MARK: - SDK State Management
    
    enum SDKRegistrationState: String {
        case unknown = "Unknown"
        case registering = "Registering..."
        case registered = "Registered"
        case failed = "Registration Failed"
    }
    
    func updateSDKRegistrationState(_ state: SDKRegistrationState, error: String? = nil) {
        sdkRegistrationState = state
        sdkError = error
        if let error = error {
            lastError = error
            lastErrorTime = Date()
            print("⚠️ SDK Error: \(error)")
        }
    }

    func handleConnected(product: DJIBaseProduct?) {
        isConnected = true
        modelName = product?.model ?? "—"

        // Start telemetry logging session (if auto-start enabled)
        if settings.autoStartSession {
            currentSessionId = logger.startSession()
            // Start telemetry logging timer
            startTelemetryLoggingTimer()
        }

        // If real product, setup delegates
        if let aircraft = product as? DJIAircraft {
            self.aircraft = aircraft

            // Battery
            battery = aircraft.battery
            battery?.delegate = self
            batteryAvailable = (battery != nil)

            // Flight controller
            flightController = aircraft.flightController
            flightController?.delegate = self
            flightControllerAvailable = (flightController != nil)
            
            // Remote controller (RC signal will be obtained from flight controller state if available)
            remoteController = aircraft.remoteController
            
            print("✅ DroneStore: Components initialized - FC: \(flightControllerAvailable), Battery: \(batteryAvailable)")
        } else {
            // Mock mode or no product
            flightControllerAvailable = false
            batteryAvailable = false
        }
        // If nil (mock mode), delegates won't be set up, but connection state is true
    }

    func handleDisconnected() {
        isConnected = false
        modelName = "—"

        battery?.delegate = nil
        flightController?.delegate = nil

        aircraft = nil
        battery = nil
        flightController = nil
        remoteController = nil
        
        flightControllerAvailable = false
        batteryAvailable = false

        batteryPercent = nil
        satellites = nil
        altitudeMeters = nil
        speedMS = nil
        latitude = nil
        longitude = nil
        gpsSignalLevel = nil
        rcSignalLevel = nil
        homeLatitude = nil
        homeLongitude = nil
        heading = nil
        
        // Stop telemetry logging timer
        stopTelemetryLoggingTimer()
        
        // End telemetry logging session (if auto-end enabled)
        if settings.autoEndSession {
            logger.endSession()
            currentSessionId = nil
            updateTelemetryLog()
        }
    }
    
    // MARK: - Telemetry Logging Rate Control
    
    private func startTelemetryLoggingTimer() {
        stopTelemetryLoggingTimer() // Ensure no duplicate timers
        
        // Use current rate from settings
        let rate = telemetryLoggingRate
        
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: rate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logTelemetryAtFixedRate()
            }
        }
        
        // Log immediately on start
        logTelemetryAtFixedRate()
    }
    
    private func stopTelemetryLoggingTimer() {
        telemetryTimer?.invalidate()
        telemetryTimer = nil
        pendingTelemetry = nil
    }
    
    private func logTelemetryAtFixedRate() {
        guard let sessionId = currentSessionId ?? logger.currentSessionId else {
            return
        }
        
        // Use pending telemetry from mock if available, otherwise create from current state
        let record: TelemetryRecord
        if let pending = pendingTelemetry {
            // Use pending record but update timestamp
            record = TelemetryRecord(
                id: pending.id,
                sessionId: sessionId,
                timestamp: Date(),
                battery: pending.battery,
                satellites: pending.satellites,
                altitude: pending.altitude,
                speed: pending.speed,
                latitude: pending.latitude,
                longitude: pending.longitude,
                heading: pending.heading,
                gpsSignalLevel: pending.gpsSignalLevel,
                rcSignalLevel: pending.rcSignalLevel,
                homeLatitude: pending.homeLatitude,
                homeLongitude: pending.homeLongitude
            )
            pendingTelemetry = nil
        } else {
            // Create record from current state
            record = TelemetryRecord(
                sessionId: sessionId,
                timestamp: Date(),
                battery: batteryPercent,
                satellites: satellites,
                altitude: altitudeMeters,
                speed: speedMS,
                latitude: latitude,
                longitude: longitude,
                heading: heading,
                gpsSignalLevel: gpsSignalLevel,
                rcSignalLevel: rcSignalLevel,
                homeLatitude: homeLatitude,
                homeLongitude: homeLongitude
            )
        }
        
        logger.log(record)
        updateTelemetryLog()
    }
    
    // MARK: - Mock Mode Support
    
    func updateWithMockRecord(_ record: TelemetryRecord) {
        // Update all telemetry from mock record
        batteryPercent = record.battery
        satellites = record.satellites
        altitudeMeters = record.altitude
        speedMS = record.speed
        latitude = record.latitude
        longitude = record.longitude
        heading = record.heading
        gpsSignalLevel = record.gpsSignalLevel
        rcSignalLevel = record.rcSignalLevel
        homeLatitude = record.homeLatitude
        homeLongitude = record.homeLongitude
        
        // Store as pending - timer will log it at fixed rate
        pendingTelemetry = record
    }
    
    private func updateTelemetryLog() {
        if let sessionId = currentSessionId ?? logger.currentSessionId {
            telemetryLog = logger.recordsForSession(sessionId)
        } else {
            telemetryLog = logger.records
        }
    }
    
    // MARK: - Data Normalization & Formatting
    
    /// Normalized altitude (uses settings for unit conversion)
    var formattedAltitude: String {
        guard let altitude = altitudeMeters, altitude >= 0 else {
            return "—"
        }
        
        switch settings.altitudeUnit {
        case .meters:
            return String(format: "%.1f m", altitude)
        case .feet:
            let altitudeFeet = altitude * 3.28084 // Convert meters to feet
            return String(format: "%.1f ft", altitudeFeet)
        }
    }
    
    /// Normalized speed (uses settings for unit conversion)
    var formattedSpeed: String {
        guard let speed = speedMS, speed >= 0 else {
            return "—"
        }
        
        switch settings.speedUnit {
        case .kmh:
            let speedKmh = speed * 3.6
            return String(format: "%.1f km/h", speedKmh)
        case .ms:
            return String(format: "%.1f m/s", speed)
        }
    }
    
    /// Normalized heading (guaranteed non-nil display)
    var formattedHeading: String {
        guard let heading = heading, heading >= 0, heading <= 360 else {
            return "—"
        }
        return String(format: "%.1f°", heading)
    }
    
    /// Normalized GPS signal level with quality indicator
    var formattedGPSSignal: String {
        guard let level = gpsSignalLevel, level >= 0 else {
            return "— (No GPS)"
        }
        let quality: String
        switch level {
        case 0...1: quality = "Poor"
        case 2...3: quality = "Fair"
        case 4...5: quality = "Good"
        default: quality = "Excellent"
        }
        return "Level \(level) (\(quality))"
    }
    
    /// Normalized RC signal level with quality indicator
    var formattedRCSignal: String {
        guard let level = rcSignalLevel, level >= 0, level <= 100 else {
            return "—"
        }
        let quality: String
        switch level {
        case 0...30: quality = "Poor"
        case 31...60: quality = "Fair"
        case 61...80: quality = "Good"
        default: quality = "Excellent"
        }
        return "\(level)% (\(quality))"
    }
    
    /// Normalized battery with status indicator
    var formattedBattery: String {
        guard let battery = batteryPercent, battery >= 0, battery <= 100 else {
            return "—"
        }
        let status: String
        switch battery {
        case 0...20: status = "⚠️ Low"
        case 21...50: status = "⚡ Medium"
        default: status = "✅ Good"
        }
        return "\(battery)% \(status)"
    }
    
    /// Normalized coordinates (guaranteed non-nil display)
    var formattedCoordinates: (lat: String, lon: String) {
        let lat = latitude.map { String(format: "%.6f", $0) } ?? "—"
        let lon = longitude.map { String(format: "%.6f", $0) } ?? "—"
        return (lat, lon)
    }
    
    /// Normalized home coordinates (guaranteed non-nil display)
    var formattedHomeCoordinates: (lat: String, lon: String) {
        let lat = homeLatitude.map { String(format: "%.6f", $0) } ?? "—"
        let lon = homeLongitude.map { String(format: "%.6f", $0) } ?? "—"
        return (lat, lon)
    }
}

// MARK: - Legacy TelemetryEntry (kept for compatibility)
struct TelemetryEntry {
    let timestamp: Date
    let battery: Int?
    let satellites: Int?
    let altitude: Double?
    let speed: Double?
    let latitude: Double?
    let longitude: Double?
    let heading: Double?
}

// MARK: - DJIBatteryDelegate
extension DroneStore: DJIBatteryDelegate {
    func battery(_ battery: DJIBattery, didUpdate state: DJIBatteryState) {
        Task { @MainActor in
            self.batteryPercent = Int(state.chargeRemainingInPercent)
        }
    }
}

// MARK: - DJIFlightControllerDelegate
extension DroneStore: DJIFlightControllerDelegate {
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        Task { @MainActor in
            // PRIVACY NOTE: We only read drone location from DJI SDK (aircraftLocation)
            // We do NOT access user's device location (CLLocationManager is not used)
            // All location data is stored locally and never sent to DJI or any third party
            // GPS / location (drone position, not user position)
            self.satellites = Int(state.satelliteCount)
            self.gpsSignalLevel = Int(state.gpsSignalLevel.rawValue)

            if let location = state.aircraftLocation {
                // This is the DRONE's location, not the user's device location
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
            } else {
                self.latitude = nil
                self.longitude = nil
            }

            // Altitude
            self.altitudeMeters = Double(state.altitude)

            // Speed (magnitude from velocity vectors)
            let vx = Double(state.velocityX)
            let vy = Double(state.velocityY)
            let vz = Double(state.velocityZ)
            self.speedMS = (vx * vx + vy * vy + vz * vz).squareRoot()
            
            // Heading
            self.heading = Double(state.attitude.yaw)
            
            // Home point
            if let homeLocation = state.homeLocation {
                self.homeLatitude = homeLocation.coordinate.latitude
                self.homeLongitude = homeLocation.coordinate.longitude
            } else {
                self.homeLatitude = nil
                self.homeLongitude = nil
            }
            
            // RC Signal - may be available through other means, for now set to nil
            // Note: Some DJI SDK versions provide RC signal through flight controller state
            
            // Don't log here - let the timer handle it at fixed rate
            // This prevents excessive logging on every callback
        }
    }
}
