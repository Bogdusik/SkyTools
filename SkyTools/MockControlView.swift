//
//  MockControlView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

/// Control view for mock drone (only visible in mock mode)
struct MockControlView: View {
    @State private var isMockRunning = true // Mock starts automatically
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Mock Drone Active")
                    .font(.headline)
            }
            
            Button(action: {
                if isMockRunning {
                    MockDroneService.shared.stop()
                    DroneStore.shared.handleDisconnected()
                } else {
                    MockDroneService.shared.start()
                    DroneStore.shared.handleConnected(product: nil)
                    DroneStore.shared.modelName = "Mock Drone (Demo)"
                }
                isMockRunning.toggle()
            }) {
                Text(isMockRunning ? "Stop Mock" : "Restart Mock")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMockRunning ? Color.orange : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Text("Mock drone is running automatically. Telemetry updates every 0.5 seconds.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            // Check if mock is actually running
            isMockRunning = true
        }
    }
}

#Preview {
    MockControlView()
}
