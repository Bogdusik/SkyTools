//
//  OnboardingView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    
    var body: some View {
        if hasSeenOnboarding {
            ContentView()
        } else {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "airplane.departure",
                    title: "Welcome to SkyTools",
                    description: "Your companion app for DJI drone flights. Track telemetry, log sessions, and analyze your flights.",
                    color: .blue
                )
                .tag(0)
                
                OnboardingPage(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Flight Analytics",
                    description: "Monitor real-time telemetry, view flight summaries, and track your drone's performance with detailed metrics.",
                    color: .green
                )
                .tag(1)
                
                OnboardingPage(
                    icon: "map",
                    title: "Flight Tracking",
                    description: "Visualize your flight path on a map, mark important events, and export flight data.",
                    color: .orange
                )
                .tag(2)
                
                OnboardingPage(
                    icon: "info.circle",
                    title: "Important Note",
                    description: "SkyTools is a companion app, not a replacement for DJI Fly. Connect your drone and start logging to begin.",
                    color: .purple
                )
                .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .overlay(
                VStack {
                    Spacer()
                    // Show "Get Started" only on last page
                    if currentPage == 3 {
                        Button(action: {
                            hasSeenOnboarding = true
                        }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Show "Next" button on other pages
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 50)
                    }
                }
            )
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(color)
                .padding(.bottom, 20)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
