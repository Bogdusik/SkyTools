# DJI Drone Connection Guide

## How SkyTools Connects to Your DJI Drone

SkyTools uses the **DJI Mobile SDK** to communicate with your drone. Here's how the connection process works:

---

## 🔌 Physical Connection Methods

### Method 1: USB Cable (Recommended)
1. **Connect your iPhone/iPad to the drone's remote controller** using a USB cable
2. The remote controller acts as a bridge between your device and the drone
3. Most DJI drones support this method (Mini 2, Mini 3, Mini 3 Pro, Mavic series)

### Method 2: Wi-Fi (For Supported Models)
1. Some newer models (like DJI Mini 3 Pro) support direct Wi-Fi connection
2. Connect your iPhone to the drone's Wi-Fi network
3. The app will detect the connection automatically

---

## 📱 Connection Flow in SkyTools

### Step 1: App Launch
When you launch SkyTools:
1. App initializes the DJI SDK
2. SDK registers with DJI servers (requires internet connection on first launch)
3. SDK starts scanning for connected products

### Step 2: Product Detection
Once the SDK is registered:
1. SDK automatically detects if a DJI product is connected
2. If found, it calls `productConnected(_:)` delegate method
3. SkyTools receives the product information (model, capabilities)

### Step 3: Telemetry Subscription
After connection:
1. SkyTools subscribes to telemetry callbacks from the SDK
2. SDK starts sending real-time data:
   - GPS position (latitude, longitude, altitude)
   - Battery level
   - Speed and heading
   - Signal strength (GPS, RC)
   - Satellite count
   - Home point coordinates

### Step 4: Data Flow
```
DJI Drone → Remote Controller → iPhone (via USB/Wi-Fi) → DJI SDK → SkyTools → UI
```

---

## ⚙️ Technical Details

### SDK Registration
- **First Launch:** Requires internet connection to register with DJI servers
- **App Key:** Your DJI Developer App Key is stored in `Info.plist`
- **Status:** Check the **System** tab to see registration status

### Automatic Connection
- SkyTools uses `DJISDKManager.startConnectionToProduct()`
- Connection happens automatically when:
  - App launches with drone already connected
  - Drone connects after app launch
  - Remote controller is powered on

### Telemetry Callbacks
SkyTools subscribes to these DJI SDK callbacks:
- `DJIFlightControllerDelegate` - Flight state, GPS, altitude, speed
- `DJIBatteryDelegate` - Battery level and status
- `DJIGPSSignalDelegate` - GPS signal strength
- `DJIRemoteControllerDelegate` - RC signal strength

---

## 🎯 What Data SkyTools Receives

### Real-time Telemetry
- **Position:** Latitude, longitude, altitude (from drone's GPS)
- **Motion:** Speed (m/s), heading (degrees)
- **Battery:** Percentage (0-100%)
- **Signals:** GPS signal level (0-5), RC signal level (0-100)
- **Satellites:** GPS satellite count
- **Home Point:** Takeoff location (latitude, longitude)

### Important Notes
- ✅ SkyTools **only reads** data from the SDK
- ✅ SkyTools **does NOT** control the drone (no flight commands)
- ✅ SkyTools **does NOT** access your device's location
- ✅ All data is stored **locally** on your device

---

## 🔧 Configuration

### For Production Use
1. Set `USE_MOCK_DRONE = false` in `SkyToolsApp.swift`
2. Register your app at [DJI Developer Portal](https://developer.dji.com/)
3. Add your App Key to `Info.plist`:
   ```xml
   <key>DJISDKAppKey</key>
   <string>YOUR_APP_KEY_HERE</string>
   ```

### For Testing (Mock Mode)
1. Set `USE_MOCK_DRONE = true` in `SkyToolsApp.swift`
2. App will simulate drone telemetry without hardware
3. All features work identically to real drone mode

---

## 🚨 Troubleshooting

### "SDK Registration Failed"
- Check internet connection (required for first registration)
- Verify App Key in `Info.plist`
- Check DJI Developer account status

### "Product Not Connected"
- Ensure remote controller is powered on
- Check USB cable connection (if using USB)
- Verify Wi-Fi connection (if using Wi-Fi)
- Check **System** tab for detailed connection status

### "No Telemetry Data"
- Wait a few seconds after connection (SDK needs time to initialize)
- Check that flight controller is available (see **System** tab)
- Ensure GPS lock (drone needs GPS signal for position data)

### "Flight Controller Not Available"
- Some drones require the propellers to be spinning (motors armed)
- Ensure the drone is powered on and ready to fly
- Check that the remote controller is properly connected

---

## 📊 Connection Status Indicators

Check the **System** tab in SkyTools to see:

- **SDK Registration:** ✅ Registered / ⚠️ Registering / ❌ Failed
- **Connection:** ✅ Connected / ❌ Disconnected
- **Product Model:** e.g., "DJI Mini 3 Pro"
- **Flight Controller:** ✅ Available / ⚠️ Not Available
- **Battery:** ✅ Available / ⚠️ Not Available

---

## 🔒 Privacy & Security

### What SkyTools Does:
- ✅ Reads telemetry data from DJI SDK
- ✅ Stores data locally on your device
- ✅ Displays data in the app UI

### What SkyTools Does NOT Do:
- ❌ Access your device's GPS location
- ❌ Send data to DJI or third-party servers
- ❌ Control the drone (no flight commands)
- ❌ Access personal information

**All data stays on your device unless you explicitly export it.**

---

## 📝 Example Connection Sequence

1. **Power on remote controller**
2. **Connect iPhone to remote controller** (USB cable)
3. **Launch SkyTools**
4. **App automatically:**
   - Registers SDK (if first launch)
   - Detects connected drone
   - Subscribes to telemetry
   - Starts logging session (if auto-start enabled)
5. **Telemetry appears in Dashboard**
6. **Flight path appears on Map**

That's it! No manual configuration needed.

---

## 🎓 For Developers

### Key Files:
- `SkyToolsApp.swift` - SDK registration and connection handling
- `DroneStore.swift` - Telemetry subscription and state management
- `AppDelegate.swift` - DJI SDK delegate methods

### Connection Delegate Methods:
```swift
func productConnected(_ product: DJIBaseProduct?)
func productDisconnected()
func appRegisteredWithError(_ error: Error?)
```

### Telemetry Subscription:
```swift
// In DroneStore.swift
flightController?.delegate = self
flightController?.startListeningToUpdates()
```

---

**Need Help?** Check the **System** tab in SkyTools for detailed connection status and error messages.
