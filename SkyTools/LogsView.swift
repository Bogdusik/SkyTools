//
//  LogsView.swift
//  SkyTools
//
//  Created by Bohdan Bozhenko on 08/01/2026.
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject var drone: DroneStore
    @State private var selectedTab = 0
    @State private var savedSessions: [UUID] = []
    @State private var showingExportSheet = false
    @State private var exportSessionId: UUID?
    @State private var exportFormat: ShareSheetView.ExportFormat = .json
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Current").tag(0)
                    Text("Sessions").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                if selectedTab == 0 {
                    CurrentSessionView(
                        showingExportSheet: $showingExportSheet,
                        exportSessionId: $exportSessionId,
                        exportFormat: $exportFormat
                    )
                } else {
                    SessionsListView(
                        savedSessions: $savedSessions,
                        showingExportSheet: $showingExportSheet,
                        exportSessionId: $exportSessionId
                    )
                    .onAppear {
                        loadSavedSessions()
                    }
                }
            }
            .navigationTitle("Flight Logs")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingExportSheet) {
                if let sessionId = exportSessionId {
                    ShareSheetView(sessionId: sessionId, format: exportFormat)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .onDisappear {
                            exportSessionId = nil
                        }
                }
            }
        }
    }
    
    private func loadSavedSessions() {
        savedSessions = TelemetryLogger.shared.loadSavedSessions()
    }
}

// MARK: - Current Session View

struct CurrentSessionView: View {
    @EnvironmentObject var drone: DroneStore
    @Binding var showingExportSheet: Bool
    @Binding var exportSessionId: UUID?
    @Binding var exportFormat: ShareSheetView.ExportFormat
    @State private var filterOption: LogFilterOption = .all
    @State private var searchText: String = ""
    
    enum LogFilterOption: String, CaseIterable {
        case all = "All"
        case last10Minutes = "Last 10 min"
        case last30Minutes = "Last 30 min"
    }
    
    private var filteredLog: [TelemetryRecord] {
        var logs = drone.telemetryLog
        
        // Apply time filter
        switch filterOption {
        case .all:
            break
        case .last10Minutes:
            let cutoff = Date().addingTimeInterval(-10 * 60)
            logs = logs.filter { $0.timestamp >= cutoff }
        case .last30Minutes:
            let cutoff = Date().addingTimeInterval(-30 * 60)
            logs = logs.filter { $0.timestamp >= cutoff }
        }
        
        // Apply search (if any)
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            logs = logs.filter { record in
                // Search in timestamp, battery, altitude, speed
                let timestampStr = record.timestamp.description.lowercased()
                let batteryStr = record.battery.map { "\($0)" } ?? ""
                let altitudeStr = record.altitude.map { String(format: "%.1f", $0) } ?? ""
                let speedStr = record.speed.map { String(format: "%.1f", $0) } ?? ""
                
                return timestampStr.contains(searchLower) ||
                       batteryStr.contains(searchLower) ||
                       altitudeStr.contains(searchLower) ||
                       speedStr.contains(searchLower)
            }
        }
        
        return logs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Telemetry Log")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(filteredLog.count) / \(drone.telemetryLog.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let sessionId = TelemetryLogger.shared.currentSessionId {
                        Text("Session: \(sessionId.uuidString.prefix(8))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Search and Filter Bar
            if !drone.telemetryLog.isEmpty {
                VStack(spacing: 8) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Filter Picker
                    Picker("Filter", selection: $filterOption) {
                        ForEach(LogFilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
            }
            
            if drone.telemetryLog.isEmpty {
                Spacer()
                VStack {
                    Text("No telemetry data yet")
                        .foregroundColor(.secondary)
                    Text("Connect a drone to start logging")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLog.isEmpty {
                Spacer()
                VStack {
                    Text("No entries match filter")
                        .foregroundColor(.secondary)
                    if !searchText.isEmpty {
                        Text("Try different search terms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(filteredLog.enumerated()), id: \.offset) { index, entry in
                        LogEntryRow(entry: entry, index: index)
                    }
                }
                .listStyle(.plain)
            }
            
            if !drone.telemetryLog.isEmpty, let sessionId = TelemetryLogger.shared.currentSessionId {
                ExportButtonsView(
                    sessionId: sessionId,
                    records: drone.telemetryLog,
                    showingExportSheet: $showingExportSheet,
                    exportSessionId: $exportSessionId,
                    exportFormat: $exportFormat
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}

// MARK: - Sessions List View

struct SessionsListView: View {
    @Binding var savedSessions: [UUID]
    @Binding var showingExportSheet: Bool
    @Binding var exportSessionId: UUID?
    @State private var selectedSessionId: UUID? = nil
    @State private var selectedSessionRecords: [TelemetryRecord] = []
    @State private var selectedSessionSummary: FlightSummary?
    @State private var searchText: String = ""
    
    private var filteredSessions: [UUID] {
        guard !searchText.isEmpty else {
            return savedSessions
        }
        
        let searchLower = searchText.lowercased()
        return savedSessions.filter { sessionId in
            let sessionIdStr = sessionId.uuidString.lowercased()
            let shortId = sessionId.uuidString.prefix(8).lowercased()
            
            // Check if search matches session ID
            if sessionIdStr.contains(searchLower) || shortId.contains(searchLower) {
                return true
            }
            
            // Check creation date
            if let date = SessionManager.shared.creationDate(for: sessionId) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let dateStr = formatter.string(from: date).lowercased()
                if dateStr.contains(searchLower) {
                    return true
                }
            }
            
            return false
        }
    }
    
    var body: some View {
        if savedSessions.isEmpty {
            Spacer()
            VStack {
                Text("No saved sessions")
                    .foregroundColor(.secondary)
                Text("Completed flights will appear here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by session ID or date...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
                
                if filteredSessions.isEmpty {
                    Spacer()
                    VStack {
                        Text("No sessions found")
                            .foregroundColor(.secondary)
                        Text("Try different search terms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSessions, id: \.self) { sessionId in
                            SessionRow(
                                sessionId: sessionId,
                                onTap: {
                                    loadSession(sessionId)
                                },
                                onExport: {
                                    exportSessionId = sessionId
                                    showingExportSheet = true
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedSessionId != nil },
                set: { if !$0 { selectedSessionId = nil } }
            )) {
                if let sessionId = selectedSessionId {
                    NavigationStack {
                        SessionDetailView(
                            sessionId: sessionId,
                            records: selectedSessionRecords,
                            summary: selectedSessionSummary
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedSessionId = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadSession(_ sessionId: UUID) {
        if let records = TelemetryLogger.shared.loadSavedRecords(for: sessionId),
           let summary = TelemetryLogger.shared.loadSavedSummary(for: sessionId) {
            selectedSessionRecords = records
            selectedSessionSummary = summary
            selectedSessionId = sessionId
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let sessionId: UUID
    let onTap: () -> Void
    let onExport: () -> Void
    
    @State private var summary: FlightSummary?
    @State private var creationDate: Date?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session \(sessionId.uuidString.prefix(8))")
                        .font(.headline)
                    Spacer()
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if let date = creationDate {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let summary = summary {
                    HStack(spacing: 16) {
                        Label(summary.formattedDuration, systemImage: "clock")
                        Label(summary.formattedMaxAltitude, systemImage: "arrow.up")
                        Label(summary.formattedTotalDistance, systemImage: "location")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadSummary()
        }
    }
    
    private func loadSummary() {
        summary = TelemetryLogger.shared.loadSavedSummary(for: sessionId)
        creationDate = SessionManager.shared.creationDate(for: sessionId)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let sessionId: UUID
    let records: [TelemetryRecord]
    let summary: FlightSummary?
    @State private var showingExportSheet = false
    @State private var exportFormat: ShareSheetView.ExportFormat = .json
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let summary = summary {
                    FlightSummarySection(summary: summary)
                }
                
                Divider()
                
                // Export buttons
                ExportButtonsView(
                    sessionId: sessionId,
                    records: records,
                    showingExportSheet: $showingExportSheet,
                    exportSessionId: Binding(
                        get: { sessionId },
                        set: { _ in }
                    ),
                    exportFormat: $exportFormat
                )
                .padding(.horizontal)
                
                Divider()
                
                Text("Telemetry Records")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(Array(records.enumerated()), id: \.offset) { index, entry in
                    LogEntryRow(entry: entry, index: index)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Session \(sessionId.uuidString.prefix(8))")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            ShareSheetView(sessionId: sessionId, format: exportFormat)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Export Buttons View

struct ExportButtonsView: View {
    let sessionId: UUID
    let records: [TelemetryRecord]
    @Binding var showingExportSheet: Bool
    @Binding var exportSessionId: UUID?
    @Binding var exportFormat: ShareSheetView.ExportFormat
    
    var body: some View {
        Menu {
            Button(action: {
                exportFormat = .json
                exportData()
            }) {
                Label("Export JSON", systemImage: "doc.text")
            }
            
            Button(action: {
                exportFormat = .csv
                exportData()
            }) {
                Label("Export CSV", systemImage: "tablecells")
            }
            
            Button(action: {
                exportFormat = .gpx
                exportData()
            }) {
                Label("Export GPX", systemImage: "map")
            }
        } label: {
            HStack {
                Image(systemName: formatIcon)
                Text("Export \(formatName)")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private var formatIcon: String {
        switch exportFormat {
        case .json: return "doc.text"
        case .csv: return "tablecells"
        case .gpx: return "map"
        }
    }
    
    private var formatName: String {
        switch exportFormat {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .gpx: return "GPX"
        }
    }
    
    private func exportData() {
        exportSessionId = sessionId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingExportSheet = true
        }
    }
}

// MARK: - Share Sheet

// MARK: - Share Sheet View

struct ShareSheetView: View {
    let sessionId: UUID
    let format: ExportFormat
    @State private var exportURL: URL?
    @State private var isLoading = true
    
    enum ExportFormat {
        case json, csv, gpx
    }
    
    var body: some View {
        Group {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
                    .onDisappear {
                        cleanupExportFile()
                    }
            } else if isLoading {
                ProgressView("Preparing export...")
                    .padding()
            } else {
                Text("Failed to prepare export")
                    .padding()
            }
        }
        .onAppear {
            prepareExport()
        }
    }
    
    private func prepareExport() {
        Task {
            let url = createShareableFile(for: sessionId, format: format)
            await MainActor.run {
                exportURL = url
                isLoading = false
                print("📤 Export: File ready at \(url.path)")
            }
        }
    }
    
    private func createShareableFile(for sessionId: UUID, format: ExportFormat) -> URL {
        let sessionRecords = TelemetryLogger.shared.recordsForSession(sessionId)
        print("📤 Export: Found \(sessionRecords.count) records for session")
        
        guard !sessionRecords.isEmpty else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("empty.txt")
        }
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let shareDir = documentsDir.appendingPathComponent("Share", isDirectory: true)
        try? FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)
        
        let fileExtension: String
        let data: Data?
        
        switch format {
        case .json:
            fileExtension = "json"
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            data = try? encoder.encode(sessionRecords)
        case .csv:
            fileExtension = "csv"
            data = ExportManager.shared.exportToCSV(records: sessionRecords)
        case .gpx:
            fileExtension = "gpx"
            data = ExportManager.shared.exportToGPX(records: sessionRecords, sessionId: sessionId)
        }
        
        let fileName = "session_\(sessionId.uuidString.prefix(8)).\(fileExtension)"
        let shareableFile = shareDir.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: shareableFile)
        
        if let data = data {
            do {
                try data.write(to: shareableFile, options: [.atomic])
                print("📤 Export: Created \(format) file, size: \(data.count) bytes")
            } catch {
                print("❌ Export: Failed to write file: \(error.localizedDescription)")
            }
        }
        
        return shareableFile
    }
    
    private func cleanupExportFile() {
        guard let url = exportURL else { return }
        
        // Small delay to ensure sharing is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Only clean up if it's in our Share directory (not saved sessions)
            if url.path.contains("/Documents/Share/") {
                try? FileManager.default.removeItem(at: url)
                print("📤 Export: Cleaned up temporary share file")
            }
        }
    }
}

// MARK: - JSON Share Item

class JSONShareItem: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String
    
    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "public.json"
    }
}

// MARK: - Share Sheet Controller

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Process items to ensure they're shareable
        var processedItems: [Any] = []
        
        for item in activityItems {
            if let url = item as? URL {
                // Verify file exists and is accessible
                if FileManager.default.fileExists(atPath: url.path) {
                    // Use file URL directly - iOS handles this better
                    processedItems.append(url)
                    print("📤 ShareSheet: Added file URL: \(url.lastPathComponent)")
                } else {
                    print("⚠️ ShareSheet: File does not exist at \(url.path)")
                }
            } else {
                processedItems.append(item)
            }
        }
        
        // Fallback to original if processing failed
        if processedItems.isEmpty {
            processedItems = activityItems
        }
        
        let controller = UIActivityViewController(
            activityItems: processedItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            popover.sourceView = window
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Exclude some activity types that might cause issues
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        // Set completion handler to log
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("❌ Share error: \(error.localizedDescription)")
            } else if completed {
                print("✅ Share completed: \(activityType?.rawValue ?? "unknown")")
            } else {
                print("ℹ️ Share cancelled")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LogEntryRow: View {
    let entry: TelemetryRecord
    let index: Int
    @ObservedObject private var eventManager = EventManager.shared
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
    
    private var nearbyEvents: [FlightEvent] {
        // Find events within 5 seconds of this entry
        let timeWindow: TimeInterval = 5.0
        return eventManager.eventsForSession(entry.sessionId)
            .filter { abs($0.timestamp.timeIntervalSince(entry.timestamp)) <= timeWindow }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                if let battery = entry.battery {
                    Label("\(battery)%", systemImage: "battery.100")
                        .font(.caption)
                }
                if let alt = entry.altitude {
                    Label(String(format: "%.1fm", alt), systemImage: "arrow.up")
                        .font(.caption)
                }
                if let speed = entry.speed {
                    Label(String(format: "%.1fm/s", speed), systemImage: "speedometer")
                        .font(.caption)
                }
                if let satellites = entry.satellites {
                    Label("\(satellites) sat", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                }
            }
            
            // Show nearby events
            if !nearbyEvents.isEmpty {
                HStack(spacing: 8) {
                    ForEach(nearbyEvents) { event in
                        HStack(spacing: 4) {
                            Image(systemName: event.type.icon)
                                .font(.caption2)
                                .foregroundColor(eventColor(event.type))
                            Text(event.type.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(eventColor(event.type).opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    LogsView()
        .environmentObject(DroneStore.shared)
}
