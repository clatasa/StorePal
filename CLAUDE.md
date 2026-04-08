# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview
StorePal is an iOS grocery list app with geofencing, built by Carlo in SwiftUI.
Active project folder: `StorePal-Xcode/StorePal/`. Minimum deployment target: iOS 26.

**Core features:**
- Multiple named grocery lists with drag-to-reorder
- List items: name, quantity, weight (lbs/kg), note, staple flag, purchase date
- Lists can be linked to a saved store (shows directions link, appears under store in My Stores)
- Saved stores (up to 10): shown on mini map, geofenced with configurable radius (global + per-store override)
- Store search via MapKit `MKLocalSearch` with configurable query
- Barcode scanner (AVFoundation + Open Food Facts API) for adding items by scan
- Distance-sorted store list, re-sorts on location update
- Shared lists via CloudKit (owner shares a 6-char code; participants join and sync in real time)
- Geofence notifications deep-link directly to the linked list when tapped

---

## Build & test commands

This is a pure Xcode project — no SPM scripts, no Makefile. All build/run actions go through Xcode or `xcodebuild`.

```bash
# Build (replace simulator name as needed)
xcodebuild -scheme StorePal \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run all tests
xcodebuild test -scheme StorePal \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -scheme StorePal \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:StorePalTests/GeofenceAlertPayloadTests

# Run a single test method
xcodebuild test -scheme StorePal \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:StorePalTests/GeofenceAlertPayloadTests/testItemsNeededFiresWhenUncheckedItemsExist
```

Tests live in `StorePalTests/StorePalTests.swift` and use `XCTest` (not Swift Testing — `import Testing` is unavailable in this target configuration).

---

## Architecture

### Entry point
`App/StorePalApp.swift` — creates `StoreViewModel` and `ListViewModel` as `@StateObject`, injects both as `.environmentObject` into `HomeView`. `AppDelegate` handles silent CloudKit pushes and notification taps (conforms to both `UIApplicationDelegate` and `UNUserNotificationCenterDelegate`).

### ViewModels
| File | Responsibility |
|---|---|
| `ViewModels/StoreViewModel.swift` | Favorites, store search, geofence sync, permissions |
| `ViewModels/ListViewModel.swift` | List/item CRUD, persistence, CloudKit push helpers, input sanitization |

Both are `@MainActor ObservableObject`. `StoreViewModel` holds a reference to `LocationService.shared` and `NotificationService.shared`.

### Models
| File | Types |
|---|---|
| `Models/GroceryList.swift` | `GroceryList`, `ListItem`, `Recipe`, `WeightUnit` |
| `Models/GroceryStore.swift` | `GroceryStore` |

### Views
| File | Contents |
|---|---|
| `Views/HomeView.swift` | `HomeView`, `StoreRow`, `StoreRadiusSheet`, `JoinListSheet`, `JoinRequest` |
| `Views/ListDetailView.swift` | `ListDetailView`, `ItemRow`, `ItemEditSheet`, `StorePickerSheet`, `RecipeRow`, `RecipeEditSheet` |
| `Views/SearchView.swift` | `SearchView` (bidirectional map↔list sync via shared `selectedStoreId`) |
| `Views/SettingsSheet.swift` | `SettingsSheet`, `PermissionRow` |
| `Views/BarcodeScannerView.swift` | `BarcodeScannerView`, `CameraPreviewView`, `CameraViewController` |
| `Views/ShareCodeSheet.swift` | `ShareCodeSheet` |

### Services
| File | Responsibility |
|---|---|
| `Services/LocationService.swift` | CoreLocation, `CLCircularRegion` geofencing, `alertPayload` decision logic |
| `Services/NotificationService.swift` | Local push notifications + `GeofenceAlertBehavior` enum |
| `Services/OpenFoodFactsService.swift` | Free barcode lookup API (no key required) |
| `Services/CloudKitService.swift` | CloudKit public DB — shared list create/join/sync/leave |

---

## Key patterns & decisions

### Persistence
`UserDefaults` JSON via `JSONEncoder`/`JSONDecoder`. Keys: `"groceryLists"` (lists), `"favorites"` (stores), `"geofenceRadius"` (global radius), `"geofenceAlertBehavior"`. No CoreData.

### Equatable on models
Both `GroceryList` and `ListItem` use **Swift-synthesized `Equatable`** (all fields compared). Do NOT add a custom `==` that only compares `id` — this caused a bug where SwiftUI skipped re-renders after state changes (checkboxes not updating).

### Input sanitization
All user-provided strings pass through `String.sanitized` (private extension at the bottom of `ListViewModel.swift`) before being stored. It strips null bytes and Unicode whitespace other than plain spaces (`\0`, `\t`, `\n`, `\r`, etc.), then trims leading/trailing spaces. Applied in `addList`, `renameList`, `addItem`, `updateItem`, `addRecipe`, `updateRecipe`.

### Geofence notification deep links
`LocationService.alertPayload(storeId:stores:lists:behavior:)` is a pure static function that decides whether to send a notification and returns `(store, listName, itemCount, listId)?`. When `listId` is non-nil, `NotificationService.sendAlert` stores it in `content.userInfo["listId"]`. `AppDelegate.userNotificationCenter(_:didReceive:)` intercepts the tap and opens `storepal://list/<uuid>`. `HomeView.onOpenURL` handles both `storepal://join/<code>` and `storepal://list/<uuid>`.

### CloudKit shared lists
Public database, `iCloud.sparkmine.carlo.storepal` container. Share flow: owner calls `shareList` → gets a 6-char code → participants call `joinList(shareCode:)`. All item/recipe mutations are pushed fire-and-forget via private helpers (`pushItemChange`, `pushItemDelete`, `pushAllItems`, `pushRecipeChange`, `pushRecipeDelete`). Silent pushes via APNs wake the app and call `syncSharedLists()`.

The `onJoin` closure in `JoinListSheet` must be typed `@MainActor (String) async throws -> Void`. Without `@MainActor`, Swift packs the String across executor boundaries when called from `Task { @MainActor in }`, corrupting small-string inline storage and causing SIGABRT.

### StoreRow bound lists
`StoreRow` accepts `boundLists: [(name: String, action: () -> Void)]` (an array, not a single optional). Multiple lists can be linked to the same store.

### Purchase date behavior
- Checking: stamps `purchasedDate = Date()`
- Unchecking: **keeps** `purchasedDate` (shown as "Last checked")
- Re-checking: overwrites with new `Date()`
- Clear Completed on staples: resets `purchasedDate = nil`

### Geofence radius
CoreLocation always receives meters. `@AppStorage("useImperial")` controls display only. Per-store override in `GroceryStore.geofenceRadiusOverride`; falls back to `StoreViewModel.geofenceRadius` (global). `didEnterRegion` reads UserDefaults directly — the SwiftUI hierarchy may not be initialized in background.

### Barcode scanner
`CameraViewController` stops the `AVCaptureSession` on first detection. "Scan Again" sets state back to `.scanning`, triggering `updateUIViewController` → `resumeScanning()`. The `isScanning: Bool` parameter on `CameraPreviewView` bridges this.

### Google Maps fallback
Try `comgooglemaps://` first; fall back to `MKMapItem` if not installed. `comgooglemaps` is in `LSApplicationQueriesSchemes` in `Info.plist`.

---

## SourceKit false positives — ignore these
SourceKit runs file-level analysis outside the Xcode target and consistently reports errors like:
- `Cannot find type 'GroceryStore' in scope`
- `Cannot find type 'ListItem' in scope`
- `Cannot find 'UIApplication' in scope`
- `Cannot declare conformance to 'NSObjectProtocol'`
- `No such module 'XCTest'` (in test files)

**These are not real build errors.** The app compiles and runs correctly in Xcode. Do not attempt to fix them.

---

## Info.plist location
`StorePal/Info.plist`

Keys of note:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `LSApplicationQueriesSchemes` → `comgooglemaps`

---

## What NOT to do
- Do not add a custom `==` to `GroceryList` or `ListItem` — breaks SwiftUI diffing
- Do not create a `StorePal/` directory alongside `StorePal-Xcode/` — deleted intentionally
- Do not add `@MainActor` to `OpenFoodFactsService` — it is an `actor`, not a class
- Do not use `import Testing` in test files — use `import XCTest`
- Do not remove `@MainActor` from the `onJoin` closure type in `JoinListSheet` — causes Swift string corruption across executor boundaries (SIGABRT)
- Do not bypass the `String.sanitized` step when storing user-provided text
