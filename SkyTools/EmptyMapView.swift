//
//  EmptyMapView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct EmptyMapView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Flight Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a flight session to see your flight path on the map")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    EmptyMapView()
}
