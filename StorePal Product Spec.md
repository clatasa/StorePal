# StorePal — Product Specification

**Version:** 1.0  
**Platform:** iPhone (iOS)  
**Last Updated:** April 2026

---

## What Is StorePal?

StorePal is a smart grocery shopping companion for iPhone. It helps you build and manage shopping lists, remember which items you buy at which stores, and alerts you automatically when you're near a store where you have items to pick up — so you never forget to stop in.

---

## Who Is It For?

Anyone who:
- Shops at multiple grocery stores regularly
- Wants to be reminded to grab things when they're already nearby
- Shares shopping responsibilities with a partner, roommate, or family member
- Wants a simple but powerful alternative to a basic notes list

---

## Core Features

### 1. Shopping Lists
- Create as many named lists as you like (e.g. "Weekly Shop", "Costco Run", "Trader Joe's Haul")
- Add items with a name, and optionally:
  - A **quantity** (e.g. "3")
  - A **weight** (e.g. "2.5 lbs" or "1 kg")
  - A **note** (e.g. "Organic if available")
- Reorder items by dragging them up or down
- Check items off as you shop — checked items show the date they were last purchased
- Mark items as **Staples** (recurring items like eggs or milk) — staples get unchecked instead of deleted when you clear your completed items, so they're always ready for next time
- **Clear Completed** removes all non-staple checked items in one tap

### 2. Barcode Scanner
- Tap the scanner button on any list to scan a product barcode with your iPhone camera
- The app looks up the product automatically using the Open Food Facts database (a free, global product directory)
- If found, the product name and brand are pre-filled — just confirm and it's added to your list
- If not found, you can type the item name manually before adding

### 3. My Stores
- Search for grocery stores near your current location using the built-in search
- Save up to 10 stores as favorites
- Saved stores appear on a map on the home screen
- The map automatically zooms to show all your saved stores
- Tap a store to zoom in on it; tap again to zoom back out
- Stores are listed in order of distance from where you are right now
- Long-press a store to set a custom alert radius or remove it

### 4. Geofence Alerts
- When you come within a set distance of a saved store, StorePal sends you a notification as a reminder to stop in
- The default alert radius is configurable (100 m to 2 km, or 0.06 to 1.24 miles)
- Each store can have its own custom alert radius, overriding the global setting

### 5. Link Lists to Stores
- Attach any list to a specific saved store
- The linked store appears as a tappable link inside the list — tap it to get directions (opens Google Maps if installed, or Apple Maps)
- On the home screen, linked lists appear beneath their store in "My Stores", and the store name appears under each list in "My Lists"
- One store can have multiple lists linked to it

### 6. Shared Lists *(requires iCloud sign-in)*
- Share any list with another person using a simple 6-character invite code
- The recipient enters the code in the "Join a List" screen to get an instant copy of the list on their device
- Changes made by either person sync automatically in real time
- Each person can check off their own items as they shop
- **Leaving a shared list:**
  - If you created the list: "Stop Sharing" removes everyone's access and deletes the shared copy
  - If you joined someone else's list: "Leave List" removes it from your device only — others keep their copy

### 7. Settings
- Toggle between **meters** and **miles** for all distance displays
- Adjust the global alert radius with a slider
- View and fix location and notification permissions
- See a status summary (how many stores saved, detection method, search area)

---

## How the Home Screen Works

The home screen has three sections:

1. **Mini Map** — shows all your saved stores as yellow pins. A green dot indicates alerts are active; grey means no stores are saved yet. Tap "Find Stores" to search.

2. **My Lists** — all your shopping lists, showing how many items are still to get. A shared list shows a small people icon. Tap a list to open it. Tap `+` to create a new list. Tap the person icon to join a shared list.

3. **My Stores** — your saved stores, sorted by distance. Any lists linked to a store appear beneath it. Long-press for options.

---

## Permissions Required

| Permission | Why It's Needed |
|---|---|
| **Location — Always** | To send alerts when you pass a saved store, even when the app isn't open |
| **Location — While Using** | Minimum needed to search for stores nearby and show the map |
| **Notifications** | To deliver the "you're near a store" alerts |
| **Camera** | To scan product barcodes |

The app works without "Always" location — you just won't receive background geofence alerts. All other features work normally.

---

## What the App Does NOT Do

- It does not track your location history or share it with anyone
- It does not require an account to use — iCloud is only needed for Shared Lists
- It does not have ads
- It does not sync your personal lists to any server (local lists stay on your device only)
- It does not require a paid subscription

---

## Data & Privacy

- All personal lists and store favorites are stored **only on your device**
- Shared lists are stored in **Apple's CloudKit** (Apple's own cloud infrastructure) and are only accessible to people you explicitly share a code with
- Barcode lookups are made to the **Open Food Facts** public database — only the barcode number is sent, nothing else
- Location data is used only to search for nearby stores and trigger geofence alerts — it is never stored or transmitted

---

## Technical Requirements

- iPhone running **iOS 17** or later
- iCloud account required for Shared Lists feature only
- Internet connection required for store search and barcode lookup; all other features work offline
