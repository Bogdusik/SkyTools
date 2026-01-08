//
//  SkyToolsApp.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI
import DJISDK

// MARK: - Configuration
// Set to true to enable mock drone mode (for demonstration without real drone)
// Set to false for production use with real DJI drone
let USE_MOCK_DRONE = false

@main
struct SkyToolsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var droneStore = DroneStore.shared
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .environmentObject(droneStore)
                .onAppear {
                    if USE_MOCK_DRONE {
                        setupMockDrone()
                    }
                }
        }
    }
    
    private func setupMockDrone() {
        print("🤖 Mock Drone Mode: Enabled")
        // Start mock drone service
        Task { @MainActor in
            // Start logging session first
            _ = TelemetryLogger.shared.startSession()
            
            MockDroneService.shared.onTelemetryUpdate = { record in
                // Update DroneStore with mock data
                DroneStore.shared.updateWithMockRecord(record)
            }
            
            // Simulate connection
            DroneStore.shared.handleConnected(product: nil)
            DroneStore.shared.modelName = "Mock Drone (Demo)"
            
            // Start mock service
            MockDroneService.shared.start()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, DJISDKManagerDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if USE_MOCK_DRONE {
            print("🤖 Mock Drone Mode: Skipping DJI SDK registration")
            Task { @MainActor in
                DroneStore.shared.updateSDKRegistrationState(.registered)
            }
            return true
        }
        
        Task { @MainActor in
            DroneStore.shared.updateSDKRegistrationState(.registering)
        }
        
        DJISDKManager.registerApp(with: self)
        print("DJI: registerApp() called")
        return true
    }

    func appRegisteredWithError(_ error: Error?) {
        Task { @MainActor in
            if let error = error {
                let errorMessage = error.localizedDescription
                print("DJI: ❌ SDK registration failed: \(errorMessage)")
                DroneStore.shared.updateSDKRegistrationState(.failed, error: errorMessage)
            } else {
                print("DJI: ✅ SDK Registered Successfully")
                DroneStore.shared.updateSDKRegistrationState(.registered)
                DJISDKManager.startConnectionToProduct()
            }
        }
    }

    func productConnected(_ product: DJIBaseProduct?) {
        let model = product?.model ?? "unknown"
        print("DJI: ✅ Product connected: \(model)")
        Task { @MainActor in
            DroneStore.shared.handleConnected(product: product)
            // Clear any previous connection errors
            DroneStore.shared.lastError = nil
        }
    }

    func productDisconnected() {
        print("DJI: ⚠️ Product disconnected")
        Task { @MainActor in
            DroneStore.shared.handleDisconnected()
            DroneStore.shared.lastError = "Product disconnected"
            DroneStore.shared.lastErrorTime = Date()
        }
    }
    
    func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
        // Optional: Handle database download progress if needed
    }
}
