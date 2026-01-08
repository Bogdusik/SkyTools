# SkyTools

<div align="center">

**A professional iOS companion app for DJI drones**

*Telemetry logging, flight analytics, and pilot utilities*

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 📱 Overview

**SkyTools** is a production-ready iOS application designed as a companion tool for DJI Mini/Mavic series drones. Unlike DJI Fly, SkyTools focuses on **telemetry logging**, **flight analytics**, and **post-flight analysis** rather than FPV control.

### Key Features

- ✅ **Real-time Telemetry Logging** - Battery, GPS, altitude, speed, heading, RC signal
- ✅ **Flight Session Management** - Automatic session tracking with persistent storage
- ✅ **Interactive Flight Map** - Visualize flight paths with MapKit (start/finish/home markers)
- ✅ **Event Markers** - Mark interesting shots, problems, wind conditions during flight
- ✅ **Flight Analytics** - KPI cards (max altitude, max speed, distance, battery drop)
- ✅ **Multi-format Export** - JSON, CSV, GPX export for analysis
- ✅ **Mock Drone Mode** - Test and develop without a physical drone
- ✅ **Privacy-First** - No user location tracking, all data stored locally

---

## 🏗️ Architecture

### Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **SDK:** DJI Mobile SDK iOS
- **Maps:** MapKit / CoreLocation
- **State Management:** Combine + ObservableObject
- **Persistence:** FileManager + UserDefaults

### Project Structure

```
SkyTools/
├── SkyTools/
│   ├── SkyToolsApp.swift          # App entry point + DJI SDK registration
│   ├── ContentView.swift          # Main TabView (4 tabs)
│   ├── DashboardView.swift        # Live telemetry + KPI cards
│   ├── FlightMapView.swift        # Interactive map with flight track
│   ├── LogsView.swift             # Session history + export
│   ├── SystemView.swift           # SDK status + settings
│   ├── OnboardingView.swift       # First launch experience
│   ├── SettingsView.swift         # App settings
│   ├── DroneStore.swift           # Central state management (ObservableObject)
│   ├── TelemetryLogger.swift      # Telemetry logging service
│   ├── TelemetryRecord.swift      # Telemetry data model
│   ├── FlightSummary.swift        # Flight analytics
│   ├── SessionManager.swift       # Session persistence
│   ├── ExportManager.swift        # CSV/GPX export
│   ├── EventManager.swift         # Event markers management
│   ├── AppSettings.swift          # Settings singleton
│   └── MockDroneService.swift     # Mock drone for testing
└── Pods/                          # CocoaPods dependencies
```

### Architecture Pattern

**MVVM-like** with centralized state management:

- **Model:** `TelemetryRecord`, `FlightEvent`, `FlightSummary`
- **View:** SwiftUI views (`DashboardView`, `FlightMapView`, etc.)
- **ViewModel:** `DroneStore` (single source of truth), `TelemetryLogger`, `EventManager`

---

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 15.0+ device or simulator
- CocoaPods installed
- DJI Developer Account (for real drone connection)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Bogdusik/SkyTools.git
   cd SkyTools
   ```

2. **Install dependencies:**
   ```bash
   pod install
   ```

3. **Open the workspace:**
   ```bash
   open SkyTools.xcworkspace
   ```

4. **Configure DJI SDK:**
   - Register your app at [DJI Developer](https://developer.dji.com/)
   - Add your App Key to `Info.plist` (if using real drone)
   - Set `USE_MOCK_DRONE = false` in `SkyToolsApp.swift` for production

5. **Build and run:**
   - Select your target device
   - Build (⌘+B) and Run (⌘+R)

---

## 🔌 Connecting a Real DJI Drone

### How It Works

SkyTools connects to your DJI drone through the **DJI Mobile SDK**:

1. **Physical Connection:**
   - Connect your iPhone/iPad to the drone's remote controller via **USB cable**
   - Or connect via **Wi-Fi** (for supported models like DJI Mini 3 Pro)

2. **SDK Connection Flow:**
   ```
   App Launch → DJI SDK Registration → Product Detection → Telemetry Subscription
   ```

3. **Automatic Telemetry:**
   - Once connected, SkyTools automatically subscribes to telemetry callbacks
   - Data flows: `DJI SDK → DroneStore → TelemetryLogger → UI`
   - No manual configuration needed

### Supported Models

- DJI Mini series (Mini 2, Mini 3, Mini 3 Pro, Mini 4 Pro)
- DJI Mavic series (Mavic Air 2, Mavic 3, etc.)
- Any DJI drone compatible with DJI Mobile SDK iOS

### Connection Steps

1. **Enable Mock Mode (for testing):**
   - Set `USE_MOCK_DRONE = true` in `SkyToolsApp.swift`
   - App will simulate drone telemetry without hardware

2. **Use Real Drone:**
   - Set `USE_MOCK_DRONE = false`
   - Connect iPhone to remote controller via USB
   - Launch SkyTools
   - App will automatically detect and connect to the drone
   - Check **System** tab for connection status

3. **Start Flight Session:**
   - Connection is automatic (if "Auto Start Session" is enabled in Settings)
   - Or manually start from Dashboard
   - Telemetry begins logging immediately

---

## 📊 Features in Detail

### 1. Real-time Telemetry Dashboard

- **Live Metrics:** Battery, altitude, speed, heading, GPS satellites
- **Signal Quality:** Visual indicators for GPS and RC signal strength
- **KPI Cards:** Max altitude, max speed, flight distance, battery drop
- **Flight Summary:** Duration, average speed, total distance

### 2. Interactive Flight Map

- **Flight Track:** Visual path of the entire flight
- **Markers:**
  - 🟢 **Start Point** - Where the flight began
  - 🔴 **End Point** - Final position (for saved sessions)
  - 🏠 **Home Point** - Takeoff location
  - 📍 **Max Distance** - Furthest point from home
  - 🎯 **Event Markers** - Custom markers (interesting shot, problem, wind)
- **Interactive Controls:**
  - Pan, zoom, rotate, pitch
  - "Follow Drone" button to return to automatic tracking

### 3. Event Markers

- **Quick Actions:** Mark interesting shots, problems, wind conditions
- **Custom Events:** Add notes and custom event types
- **Context:** Events are saved with GPS coordinates and timestamps
- **Visualization:** Displayed on map and in logs

### 4. Session Management

- **Automatic Sessions:** Start/end based on drone connection (configurable)
- **Persistent Storage:** All sessions saved to `Documents/Sessions/`
- **Session History:** Browse past flights with date/time
- **Export Options:** JSON (full telemetry), CSV (tabular), GPX (route)

### 5. Settings & Customization

- **Logging Frequency:** 1 Hz / 2 Hz / 5 Hz
- **Units:** Speed (m/s ↔ km/h), Altitude (m ↔ ft)
- **Auto Session:** Enable/disable automatic session start/end
- **Event Markers:** Toggle event marker functionality

---

## 🧪 Testing with Mock Drone

SkyTools includes a **Mock Drone Service** for development and testing:

- **No Hardware Required:** Test all features without a physical drone
- **Realistic Simulation:** Generates realistic telemetry data
- **Full Feature Access:** All features work identically to real drone mode

To enable:
```swift
let USE_MOCK_DRONE = true  // In SkyToolsApp.swift
```

---

## 🔒 Privacy & Security

**SkyTools is privacy-first:**

- ✅ **No User Location Tracking** - App does NOT access device GPS via `CLLocationManager`
- ✅ **Drone Data Only** - Only reads drone position from DJI SDK
- ✅ **Local Storage** - All data stored locally on device
- ✅ **No Cloud Sync** - No automatic data transmission
- ✅ **User-Controlled Export** - You decide when to share data

See [PRIVACY.md](PRIVACY.md) for full privacy policy.

---

## 📁 Data Export Formats

### JSON Export
Complete telemetry log with all fields:
```json
{
  "sessionId": "...",
  "timestamp": "2026-01-08T10:30:00Z",
  "battery": 85,
  "altitude": 45.2,
  "speed": 8.5,
  "latitude": 55.8642,
  "longitude": -4.2518,
  ...
}
```

### CSV Export
Tabular format for spreadsheet analysis:
```csv
timestamp,battery,altitude,speed,latitude,longitude,heading
2026-01-08 10:30:00,85,45.2,8.5,55.8642,-4.2518,180.5
...
```

### GPX Export
Flight route for Google Earth / QGIS:
```xml
<gpx>
  <trk>
    <trkseg>
      <trkpt lat="55.8642" lon="-4.2518">
        <ele>45.2</ele>
        <time>2026-01-08T10:30:00Z</time>
      </trkpt>
      ...
    </trkseg>
  </trk>
</gpx>
```

---

## 🛠️ Development

### Project Setup

1. **CocoaPods:**
   ```bash
   pod install
   pod update
   ```

2. **Xcode Configuration:**
   - Open `SkyTools.xcworkspace` (not `.xcodeproj`)
   - Select your development team
   - Configure signing & capabilities

3. **DJI SDK:**
   - Register at [DJI Developer](https://developer.dji.com/)
   - Add App Key to `Info.plist` (for production)

### Code Quality

- **Architecture:** MVVM-like with centralized state
- **Error Handling:** Comprehensive error states and user feedback
- **Performance:** Fixed-rate logging (1/2/5 Hz), memory management (max 1000 records)
- **Documentation:** Key components have inline comments

### Testing

- **Mock Mode:** Full feature testing without hardware
- **Real Drone:** Field testing with actual DJI drone
- **Edge Cases:** Empty states, disconnection handling, error recovery

---

## 📸 Screenshots

*Screenshots coming soon*

---

## 🤝 Contributing

This is a portfolio project, but contributions are welcome:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **DJI** - For the Mobile SDK
- **Apple** - For SwiftUI and iOS frameworks
- **Open Source Community** - For inspiration and tools

---

## 📧 Contact

**Bohdan Bozhenko**

- Portfolio: [GitHub](https://github.com/Bogdusik)
- Email: [your.email@example.com]

---

## 🎯 Project Status

**SkyTools v1.1** - Production Ready ✅

- ✅ All core features implemented
- ✅ UI polished and user-friendly
- ✅ Privacy-first architecture
- ✅ Ready for real-world use
- ✅ Portfolio-ready codebase

---

<div align="center">

**Built with ❤️ using Swift & SwiftUI**

*For DJI drone pilots who want more control over their flight data*

</div>
