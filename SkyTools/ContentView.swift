//
//  ContentView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var drone: DroneStore
    @State private var showingSettings = false
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
            
            FlightMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
            
            SystemView()
                .tabItem {
                    Label("System", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DroneStore.shared)
}
