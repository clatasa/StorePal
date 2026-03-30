# StorePal — Setup Guide

## No Third-Party Dependencies

StorePal uses Apple-native frameworks only — no API keys or SPM packages needed.

| Framework | Used for |
|-----------|----------|
| MapKit | Map display + grocery store search |
| CoreLocation | Geo-fencing (CLRegion monitoring) |
| UserNotifications | Local alerts when entering a store's region |

---

## 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - **Product Name**: `StorePal`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Deployment Target**: iOS 18.0
4. Delete the auto-generated `ContentView.swift`

---

## 2. Add the Source Files

Drag all folders into the Xcode Project Navigator. When prompted, check **"Copy items if needed"** and make sure your app target is ticked.

```
App/
  StorePalApp.swift
Models/
  GroceryStore.swift
Services/
  LocationService.swift
  NotificationService.swift
ViewModels/
  StoreViewModel.swift
Views/
  HomeView.swift        ← also contains StoreRow
  SearchView.swift
  SettingsSheet.swift   ← also contains PermissionRow
```

---

## 3. Configure Info.plist

Add these two keys (Xcode → select your target → Info tab, or edit the plist directly):

| Key | Value |
|-----|-------|
| `NSLocationWhenInUseUsageDescription` | `StorePal uses your location to find nearby grocery stores.` |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | `StorePal needs background location access to alert you when you pass a saved store.` |

> **Why "Always"?** CLRegion monitoring fires when the app is backgrounded or killed.
> iOS requires this key and the user to grant "Always" permission for that to work.

---

## 4. No Additional Capabilities Needed

CLRegion monitoring works without adding a Background Modes capability.
If you later add significant-change location updates, add "Location updates" under Background Modes at that point.

---

## 5. Build & Run

> **Run on a real device.** Location services are unreliable in the iOS Simulator.

1. Launch the app on your device
2. Grant **"Always Allow"** location access when prompted
3. Grant **Notifications** access when prompted
4. Tap the **magnifying glass** (top-right) to search for nearby stores
5. Tap ⭐ on up to 3 stores to save them as favorites
6. Tap the **gear icon** to adjust the alert radius (100 m – 2 km, default 500 m)

---

## How It Works

```
Home Screen
├── Mini map    → non-interactive, shows saved stores as yellow ⭐ pins
├── "My Stores" card  → list of up to 3 favorites with ⭐ toggle
└── Toolbar     → 🔍 search   ⚙️ settings

Search Sheet
├── Full-screen interactive map with blue (unsaved) / yellow (saved) pins
└── Results panel   → scrollable list, ⭐ to add/remove favorites

Settings Sheet
├── Radius slider   → 100 m – 2 km, updates all geo-fences immediately
└── Permission rows → location (green/orange/red) + notifications
```

### Geo-fence alert flow
1. User saves a store → `CLCircularRegion` registered with configured radius
2. Device crosses into the region (even with app killed) → iOS wakes the app
3. `LocationService.locationManager(_:didEnterRegion:)` fires
4. Reads saved stores from `UserDefaults`, fires a `UNUserNotificationCenter` local notification

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No geo-fence alerts | Location permission must be **Always** (not "When In Use"). Go to iOS Settings → Privacy & Security → Location Services → StorePal → Always. |
| Empty search results | Location was unavailable; move outdoors and tap "Search Here" again. |
| "Alerts active" badge stays orange | Grant Always location in Settings (see above). |
| Stores not saved after reinstall | Geo-fences are rebuilt automatically from UserDefaults on first launch. |
