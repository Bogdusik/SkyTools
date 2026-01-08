//
//  FlightMapView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI
import MapKit
import CoreLocation

/// Flight map view displaying drone flight path
/// PRIVACY: Uses MapKit for display only. Does NOT request user location permissions.
/// Only displays drone position data received from DJI SDK (stored locally).
struct FlightMapView: View {
    @EnvironmentObject var drone: DroneStore
    @ObservedObject private var eventManager = EventManager.shared
    @State private var selectedSessionId: UUID?
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.8642, longitude: -4.2518),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isFollowingDrone = true // Track if user is following drone
    @State private var accumulatedTrackPoints: [CLLocationCoordinate2D] = [] // Accumulate track points for live tracking
    @State private var flightStartPoint: CLLocationCoordinate2D? // Store flight start point (home)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map with border - full screen
                if hasTrackData || drone.isConnected {
                    FlightMapViewRepresentable(
                        region: $mapRegion,
                        annotations: mapAnnotations,
                        trackPoints: trackPoints,
                        isFollowingDrone: $isFollowingDrone
                    )
                    .overlay(
                        // Thin border around map
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        EventManager.shared.loadEvents()
                        isFollowingDrone = true
                        // Don't reset accumulatedTrackPoints - keep the path!
                        // Only reset if starting a new session
                        if let currentSessionId = TelemetryLogger.shared.currentSessionId {
                            // Load existing points from logger if available
                            let records = TelemetryLogger.shared.recordsForSession(currentSessionId)
                            if accumulatedTrackPoints.isEmpty && !records.isEmpty {
                                // Load from saved records
                                accumulatedTrackPoints = records
                                    .compactMap { record -> CLLocationCoordinate2D? in
                                        guard let lat = record.latitude, let lon = record.longitude else { return nil }
                                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                                    }
                            }
                        }
                        // Start accumulating if drone is already connected
                        if drone.isConnected {
                            updateAccumulatedTrackPoints()
                            updateFlightStartPoint()
                        }
                        // Delay to avoid cycles
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            updateMapRegion()
                        }
                    }
                    .onChange(of: drone.telemetryLog.count) { _ in
                        // Throttle updates to avoid cycles
                        if isFollowingDrone {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                updateMapRegion()
                            }
                        }
                    }
                    .onChange(of: drone.latitude) { _ in
                        // Update accumulated track points when drone moves
                        updateAccumulatedTrackPoints()
                        updateFlightStartPoint()
                        
                        // Update region when drone moves (throttled) - only if following
                        if isFollowingDrone && drone.isConnected {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                updateMapRegion()
                            }
                        }
                    }
                    .onChange(of: drone.longitude) { _ in
                        // Update accumulated track points when drone moves
                        updateAccumulatedTrackPoints()
                        updateFlightStartPoint()
                    }
                    .onChange(of: drone.homeLatitude) { _ in
                        // Update start point when home position changes
                        updateFlightStartPoint()
                    }
                    .onChange(of: drone.homeLongitude) { _ in
                        // Update start point when home position changes
                        updateFlightStartPoint()
                    }
                    .onChange(of: drone.isConnected) { isConnected in
                        if !isConnected {
                            // Don't clear - keep the path for viewing!
                            // Only clear if explicitly starting a new session
                        } else {
                            // Start accumulating when connected
                            updateAccumulatedTrackPoints()
                            updateFlightStartPoint()
                        }
                    }
                    .onChange(of: TelemetryLogger.shared.currentSessionId) { newSessionId in
                        // Reset accumulated points when session changes
                        if newSessionId != nil {
                            // Only reset if we're not viewing a saved session
                            if selectedSessionId == nil {
                                accumulatedTrackPoints.removeAll()
                                flightStartPoint = nil
                            }
                        }
                    }
                } else {
                    EmptyMapView()
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Event Markers Panel - top left (collapsible)
                if AppSettings.shared.eventMarkersEnabled {
                    VStack {
                        HStack {
                            EventMarkersPanel()
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8) // Closer to nav bar
                        Spacer()
                    }
                }
                
                // Follow Drone button - bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if !isFollowingDrone {
                            Button(action: {
                                selectedSessionId = nil // Show current live session
                                isFollowingDrone = true
                                // Don't clear accumulatedTrackPoints - keep the path!
                                // Only merge with saved records if they exist
                                if let currentSessionId = TelemetryLogger.shared.currentSessionId {
                                    let records = TelemetryLogger.shared.recordsForSession(currentSessionId)
                                    let savedPoints = records
                                        .compactMap { record -> CLLocationCoordinate2D? in
                                            guard let lat = record.latitude, let lon = record.longitude else { return nil }
                                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                                        }
                                    // Merge saved points with accumulated (avoid duplicates)
                                    for point in savedPoints {
                                        if !accumulatedTrackPoints.contains(where: { 
                                            abs($0.latitude - point.latitude) < 0.00001 && 
                                            abs($0.longitude - point.longitude) < 0.00001 
                                        }) {
                                            accumulatedTrackPoints.append(point)
                                        }
                                    }
                                }
                                updateFlightStartPoint()
                                updateMapRegion()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.north.fill")
                                    Text("Follow Drone")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 20) // Closer to nav bar
                    .padding(.bottom, 20) // Reduced bottom padding
                }
            }
            .navigationTitle("Flight Map")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black.opacity(0.7), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    
    private var currentSessionId: UUID? {
        selectedSessionId ?? TelemetryLogger.shared.currentSessionId
    }
    
    private var trackPoints: [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        
        // Get records from current or selected session
        if let sessionId = currentSessionId {
            let records = TelemetryLogger.shared.recordsForSession(sessionId)
            
            points = records
                .compactMap { record -> CLLocationCoordinate2D? in
                    guard let lat = record.latitude, let lon = record.longitude else { 
                        return nil 
                    }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
        }
        
        // Combine saved records with accumulated live points
        return points + accumulatedTrackPoints
    }
    
    private var hasTrackData: Bool {
        !trackPoints.isEmpty || drone.isConnected
    }
    
    private var mapAnnotations: [MapAnnotation] {
        var annotations: [MapAnnotation] = []
        
        guard let sessionId = currentSessionId else { return annotations }
        
        let records = TelemetryLogger.shared.recordsForSession(sessionId)
        let events = eventManager.eventsForSession(sessionId)
        
        // Current drone position (if connected and has location)
        if drone.isConnected,
           let lat = drone.latitude, let lon = drone.longitude {
            annotations.append(MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                marker: AnyView(CurrentDroneMarker())
            ))
        }
        
        // Start point (only if not showing current position or if it's a saved session)
        if selectedSessionId != nil || !drone.isConnected,
           let firstRecord = records.first,
           let lat = firstRecord.latitude, let lon = firstRecord.longitude {
            annotations.append(MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                marker: AnyView(StartMarker())
            ))
        }
        
        // End point (only for saved sessions)
        if selectedSessionId != nil,
           let lastRecord = records.last,
           let lat = lastRecord.latitude, let lon = lastRecord.longitude {
            annotations.append(MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                marker: AnyView(EndMarker())
            ))
        }
        
        // Home point / Start point
        // First try to get from saved records
        if let firstRecord = records.first,
           let lat = firstRecord.homeLatitude, let lon = firstRecord.homeLongitude {
            annotations.append(MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                marker: AnyView(HomeMarker())
            ))
        } else if let startPoint = flightStartPoint {
            // Use stored flight start point for live tracking
            annotations.append(MapAnnotation(
                coordinate: startPoint,
                marker: AnyView(HomeMarker())
            ))
        } else if let firstPoint = accumulatedTrackPoints.first {
            // Use first accumulated point as start
            annotations.append(MapAnnotation(
                coordinate: firstPoint,
                marker: AnyView(HomeMarker())
            ))
        } else if drone.isConnected,
                  let homeLat = drone.homeLatitude, let homeLon = drone.homeLongitude {
            // Use drone's home position
            annotations.append(MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: homeLat, longitude: homeLon),
                marker: AnyView(HomeMarker())
            ))
        }
        
        // Max distance point (furthest from home)
        if let homeLat = records.first?.homeLatitude,
           let homeLon = records.first?.homeLongitude {
            var maxDistance: Double = 0
            var maxDistanceRecord: TelemetryRecord?
            
            for record in records {
                guard let lat = record.latitude, let lon = record.longitude else { continue }
                let distance = calculateDistance(
                    lat1: homeLat, lon1: homeLon,
                    lat2: lat, lon2: lon
                )
                if distance > maxDistance {
                    maxDistance = distance
                    maxDistanceRecord = record
                }
            }
            
            if let record = maxDistanceRecord,
               let lat = record.latitude, let lon = record.longitude {
                annotations.append(MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    marker: AnyView(MaxDistanceMarker(distance: maxDistance))
                ))
            }
        }
        
        // Event markers
        for event in events {
            if let lat = event.latitude, let lon = event.longitude {
                annotations.append(MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    marker: AnyView(EventMarker(event: event))
                ))
            }
        }
        
        return annotations
    }
    
    private func updateMapRegion() {
        let points = trackPoints
        guard !points.isEmpty else { return }
        
        let lats = points.map { $0.latitude }
        let lons = points.map { $0.longitude }
        
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )
        
        mapRegion = MKCoordinateRegion(center: center, span: span)
    }
    
    private func updateAccumulatedTrackPoints() {
        // Update accumulated track points asynchronously to avoid state modification during view update
        guard drone.isConnected,
              let lat = drone.latitude, let lon = drone.longitude else {
            return
        }
        
        let currentPoint = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        // Add to accumulated points if it's a new position (with tolerance)
        // Use larger tolerance to avoid too many duplicate points
        let tolerance: Double = 0.0001 // ~11 meters
        
        if accumulatedTrackPoints.isEmpty {
            // Always add first point (this is the start point)
            accumulatedTrackPoints.append(currentPoint)
            // Also set as flight start point
            flightStartPoint = currentPoint
        } else if let lastPoint = accumulatedTrackPoints.last {
            // Check if this is a new position (far enough from last point)
            let distance = abs(lastPoint.latitude - currentPoint.latitude) + abs(lastPoint.longitude - currentPoint.longitude)
            if distance > tolerance {
                accumulatedTrackPoints.append(currentPoint)
            }
        }
    }
    
    private func updateFlightStartPoint() {
        // Update flight start point from drone's home position or first accumulated point
        if let homeLat = drone.homeLatitude, let homeLon = drone.homeLongitude {
            flightStartPoint = CLLocationCoordinate2D(latitude: homeLat, longitude: homeLon)
        } else if flightStartPoint == nil, let firstPoint = accumulatedTrackPoints.first {
            flightStartPoint = firstPoint
        }
    }
    
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

// MARK: - Event Markers Panel (Collapsible)

struct EventMarkersPanel: View {
    @EnvironmentObject var drone: DroneStore
    @ObservedObject private var eventManager = EventManager.shared
    @State private var isExpanded = false
    @State private var showingEventSheet = false
    @State private var selectedEventType: FlightEvent.EventType = .interesting
    @State private var eventNote: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 8) {
                    // Quick action buttons
                    HStack(spacing: 8) {
                        CompactEventButton(
                            type: .interesting,
                            icon: "camera.fill",
                            color: .blue
                        ) {
                            markEvent(type: .interesting)
                        }
                        
                        CompactEventButton(
                            type: .problem,
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        ) {
                            markEvent(type: .problem)
                        }
                        
                        CompactEventButton(
                            type: .wind,
                            icon: "wind",
                            color: .orange
                        ) {
                            markEvent(type: .wind)
                        }
                        
                        CompactEventButton(
                            type: .custom,
                            icon: "tag.fill",
                            color: .purple
                        ) {
                            showingEventSheet = true
                        }
                    }
                    
                    // Recent events (compact)
                    if !recentEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recentEvents.prefix(2)) { event in
                                HStack(spacing: 6) {
                                    Image(systemName: event.type.icon)
                                        .font(.caption2)
                                        .foregroundColor(eventColor(event.type))
                                    Text(event.type.rawValue)
                                        .font(.caption2)
                                    if let note = event.note {
                                        Text("• \(note)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(event.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Mark Event")
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                    if !recentEvents.isEmpty {
                        Text("\(recentEvents.count)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .frame(maxWidth: 200) // Shorter width
        .sheet(isPresented: $showingEventSheet) {
            CustomEventSheet(
                eventType: $selectedEventType,
                note: $eventNote,
                onSave: {
                    markEvent(type: selectedEventType, note: eventNote.isEmpty ? nil : eventNote)
                    eventNote = ""
                    showingEventSheet = false
                },
                onCancel: {
                    eventNote = ""
                    showingEventSheet = false
                }
            )
        }
        .onAppear {
            EventManager.shared.loadEvents()
        }
    }
    
    private var recentEvents: [FlightEvent] {
        guard let sessionId = TelemetryLogger.shared.currentSessionId else { return [] }
        return eventManager.eventsForSession(sessionId)
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func markEvent(type: FlightEvent.EventType, note: String? = nil) {
        guard let sessionId = TelemetryLogger.shared.currentSessionId else { return }
        
        let event = eventManager.addEvent(
            sessionId: sessionId,
            type: type,
            note: note,
            latitude: drone.latitude,
            longitude: drone.longitude,
            altitude: drone.altitudeMeters
        )
        
        print("📌 Marked event: \(type.rawValue) at \(event.timestamp)")
    }
    
    private func eventColor(_ type: FlightEvent.EventType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct CompactEventButton: View {
    let type: FlightEvent.EventType
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(type.rawValue)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
        }
    }
}

// MARK: - Map Annotations

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let marker: AnyView
}

// MARK: - Markers

struct CurrentDroneMarker: View {
    var body: some View {
        ZStack {
            // Outer pulse circle
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
            
            // Middle circle
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 40, height: 40)
            
            // Inner circle with emoji
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                Text("🛸")
                    .font(.title3)
            }
        }
    }
}

struct StartMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 20, height: 20)
            Text("S")
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
        }
    }
}

struct EndMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 20, height: 20)
            Text("E")
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
        }
    }
}

struct HomeMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
            Image(systemName: "house.fill")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

struct MaxDistanceMarker: View {
    let distance: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 18, height: 18)
            Text("M")
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
        }
    }
}

struct EventMarker: View {
    let event: FlightEvent
    
    var body: some View {
        ZStack {
            Circle()
                .fill(eventColor)
                .frame(width: 24, height: 24)
            Image(systemName: event.type.icon)
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
    
    private var eventColor: Color {
        switch event.type.color {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Map View Representable

/// Wraps MKMapView for SwiftUI integration
/// Handles:
/// - Flight path polyline rendering (blue line)
/// - Custom annotation markers (start, end, home, events, current position)
/// - Region updates with throttling to prevent cycles
struct FlightMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [MapAnnotation]
    let trackPoints: [CLLocationCoordinate2D]
    @Binding var isFollowingDrone: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        // Enable user interaction (pan, zoom, etc.)
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.showsUserLocation = false // We don't need user location
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove old annotations and overlays first
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add flight path polyline (make it more visible)
        if trackPoints.count > 1 {
            // Need at least 2 points for a visible line
            let polyline = MKPolyline(coordinates: trackPoints, count: trackPoints.count)
            mapView.addOverlay(polyline)
        } else if trackPoints.count == 1 {
            // Even single point - add as polyline (will show as a dot)
            let polyline = MKPolyline(coordinates: trackPoints, count: trackPoints.count)
            mapView.addOverlay(polyline)
        }
        
        // Add annotations
        for annotation in annotations {
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = annotation.coordinate
            mapView.addAnnotation(mkAnnotation)
        }
        
        // Update region only if following drone (to allow user to pan/zoom freely)
        if isFollowingDrone && (!trackPoints.isEmpty || !annotations.isEmpty) {
            DispatchQueue.main.async {
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Detect when user manually moves the map
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(annotations: annotations, parent: self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let annotations: [MapAnnotation]
        var parent: FlightMapViewRepresentable?
        
        init(annotations: [MapAnnotation], parent: FlightMapViewRepresentable) {
            self.annotations = annotations
            self.parent = parent
        }
        
        // Detect when user manually moves the map
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // If user manually moved the map, stop following
            if !animated && parent?.isFollowingDrone == true {
                // Small delay to check if this was programmatic or user action
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let currentRegion = self.parent?.region,
                       abs(mapView.region.center.latitude - currentRegion.center.latitude) > 0.0001 ||
                       abs(mapView.region.center.longitude - currentRegion.center.longitude) > 0.0001 {
                        self.parent?.isFollowingDrone = false
                    }
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 5.0 // Make track more visible
                renderer.alpha = 0.9
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let coordinate = annotation.coordinate
            
            // Find matching annotation
            guard let mapAnnotation = annotations.first(where: { 
                abs($0.coordinate.latitude - coordinate.latitude) < 0.0001 &&
                abs($0.coordinate.longitude - coordinate.longitude) < 0.0001
            }) else {
                return nil
            }
            
            let identifier = "FlightAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.canShowCallout = false
            
            // Convert SwiftUI view to UIImage
            let hostingView = UIHostingController(rootView: mapAnnotation.marker)
            hostingView.view.backgroundColor = .clear
            
            // Use appropriate size for markers
            let size = CGSize(width: 50, height: 50)
            hostingView.view.frame = CGRect(origin: .zero, size: size)
            
            // Force layout before rendering
            hostingView.view.setNeedsLayout()
            hostingView.view.layoutIfNeeded()
            
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
                hostingView.view.drawHierarchy(in: hostingView.view.bounds, afterScreenUpdates: true)
            }
            
            annotationView?.image = image
            annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)
            
            return annotationView
        }
    }
}
