# Catchup iOS App - Setup Guide

## Prerequisites

- macOS Ventura (13.0) or later
- Xcode 15.0 or later
- iOS 16.0+ device or simulator
- Apple Developer account (for device testing)

## Project Setup

### 1. Open the Project

You have two options to open and run this project:

#### Option A: Open in Xcode (Recommended)
Since this is a complete project structure without an actual `.xcodeproj` file generated, you'll need to create one:

1. Open Xcode
2. Select "Create a new Xcode project"
3. Choose "iOS" → "App"
4. Fill in:
   - Product Name: `CatchupApp`
   - Team: Your development team
   - Organization Identifier: `com.yourname.catchup`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
5. Save in a temporary location
6. Copy all the files from this repository into the new project
7. Add files to the project in Xcode (File → Add Files to "CatchupApp")

#### Option B: Use Swift Package Manager
```bash
cd catchup_os
swift build
```

### 2. Configure the Project

#### Set Your Development Team
1. Select the project in the navigator
2. Select the "CatchupApp" target
3. Go to "Signing & Capabilities"
4. Select your Team

#### Configure Widget Extension
1. Select the "CatchupWidget" target
2. Go to "Signing & Capabilities"
3. Select your Team
4. Ensure the bundle identifier is: `com.yourname.catchup.CatchupWidget`

### 3. Enable Required Capabilities

The app needs the following capabilities (already configured in Info.plist):

- **Push Notifications** (optional, for future features)
- **Background Modes** → Background fetch (for widget updates)

### 4. Build and Run

1. Select your target device or simulator (iOS 16.0+)
2. Press ⌘R or click the Run button
3. Grant notification permissions when prompted

## Project Structure Overview

```
CatchupApp/
├── CatchupApp.swift          # App entry point with SwiftData setup
├── Info.plist                # App permissions and configuration
├── Assets.xcassets/          # Images and colors
│   ├── AppIcon.appiconset/   # App icon
│   └── AccentColor.colorset/ # Accent color
├── Models/
│   ├── Contact.swift         # Contact data model
│   └── CheckIn.swift         # Check-in data model
├── Views/
│   ├── ContentView.swift     # Main list view
│   ├── AddContactView.swift  # Add contact form
│   ├── ContactDetailView.swift
│   ├── CheckInSheetView.swift
│   ├── EditContactView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── ContactRowView.swift
│       ├── StatsHeaderView.swift
│       ├── CategoryFilterButton.swift
│       └── EmptyStateView.swift
└── Managers/
    └── NotificationManager.swift

CatchupWidget/
├── CatchupWidget.swift       # Widget implementation
└── Info.plist
```

## Key Features Implemented

### ✅ Core Features
- [x] Contact management with categories
- [x] Customizable check-in frequencies
- [x] Multiple check-in types
- [x] Notes and journal for each interaction
- [x] Smart notifications
- [x] Home screen widgets (3 sizes)
- [x] Search and filter
- [x] Data export (JSON)

### 📱 UI/UX Features
- [x] Modern SwiftUI interface
- [x] Smooth animations
- [x] Dark mode support (automatic)
- [x] Responsive layouts for all device sizes
- [x] Intuitive navigation
- [x] Visual indicators for overdue contacts

## Testing the App

### 1. Add Your First Contact
- Tap the + button
- Fill in the contact details
- Set a check-in frequency (try "Week" for quick testing)
- Save

### 2. Record a Check-in
- Tap on the contact
- Tap "Record Check-in"
- Select a type (call, text, meeting, etc.)
- Add notes (optional)
- Save

### 3. Test Notifications
- Add a contact with a short frequency (7 days)
- Record a check-in dated 7 days ago
- Check notification settings to ensure they're enabled
- Wait for the notification (or change device date for testing)

### 4. Add a Widget
- Long press on home screen
- Tap + button
- Search "Catchup"
- Select a size
- Add to home screen

## Troubleshooting

### Notifications Not Working
1. Check Settings app → Catchup → Notifications are enabled
2. Ensure the app has permission: Settings → Notifications → Catchup
3. Check that contacts have check-in dates set

### Widget Not Updating
1. Widgets update on a system-controlled schedule
2. Long press widget → Edit Widget to force refresh
3. Remove and re-add the widget

### Build Errors
1. Ensure Xcode is updated to 15.0+
2. Clean build folder (⌘⇧K)
3. Delete DerivedData folder
4. Restart Xcode

### SwiftData Errors
1. Delete the app from simulator/device
2. Clean build folder
3. Rebuild and run

## Customization

### Change App Colors
Edit `CatchupApp/Assets.xcassets/AccentColor.colorset/Contents.json`

### Modify Check-in Frequencies
Edit the `frequencyOptions` array in:
- `AddContactView.swift`
- `EditContactView.swift`

### Add New Categories
Edit the `ContactCategory` enum in `Models/Contact.swift`

### Customize Notifications
Edit the `NotificationManager.swift` file to change notification timing and content

## Data Storage

- All data is stored locally using SwiftData
- Data location: App's Documents directory
- No cloud sync (can be added via iCloud)
- Export data from Settings → Export Data

## Performance Tips

- SwiftData automatically manages memory and cache
- Widgets update on system schedule to preserve battery
- Notifications are scheduled locally (no server needed)

## Next Steps

Consider implementing these enhancements:
- iCloud sync for multiple devices
- Contact photos from system Contacts
- Advanced analytics dashboard
- Calendar integration
- Siri shortcuts
- Custom notification sounds
- Group contacts
- CSV import/export

## Support

For issues or questions:
1. Check the README.md for feature documentation
2. Review the code comments for implementation details
3. Open an issue on GitHub

## License

Open source - feel free to modify and distribute.

---

Happy connecting! 🎉

