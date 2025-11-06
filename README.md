# Catchup - Friendship Tracker

A beautiful iOS app to help you maintain meaningful relationships through consistent check-ins with friends and family.

## Features

### Core Functionality
- **Contact Management**: Add and organize contacts with categories (Personal, Work, Family, Friends)
- **Customizable Check-in Frequency**: Set personalized intervals for each contact (weekly, monthly, quarterly, etc.)
- **Check-in Tracking**: Record interactions with different types (call, text, in-person, video, email)
- **Notes & Journal**: Add notes to each check-in and review your interaction history
- **Smart Reminders**: Get notifications when it's time to reach out
- **Home Screen Widget**: See who needs attention at a glance (small, medium, and large sizes)

### Advanced Features
- **Categories**: Organize contacts into Personal, Work, Family, and Friends
- **Multiple Check-in Types**: Track different types of interactions
- **Overdue Tracking**: Visual indicators for overdue check-ins
- **Statistics**: View total contacts and those needing attention
- **Data Export**: Export all your data as JSON for backup
- **Search & Filter**: Find contacts quickly by name or category
- **Sorting Options**: Sort by name, due date, or recent check-ins
- **Quick Actions**: Call, text, or email directly from contact details

## Technical Stack

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: For local data persistence
- **WidgetKit**: Home screen widgets
- **UserNotifications**: Reminder system
- **iOS 16.0+**: Minimum deployment target

## Project Structure

```
CatchupApp/
├── CatchupApp.swift          # App entry point
├── Info.plist                # App configuration
├── Models/
│   ├── Contact.swift         # Contact model with relationships
│   └── CheckIn.swift         # Check-in model
├── Views/
│   ├── ContentView.swift     # Main contacts list
│   ├── AddContactView.swift  # Add new contact
│   ├── ContactDetailView.swift  # Contact details & history
│   ├── CheckInSheetView.swift   # Record check-in
│   ├── EditContactView.swift    # Edit contact
│   ├── SettingsView.swift       # Settings & data export
│   └── Components/
│       ├── ContactRowView.swift
│       ├── StatsHeaderView.swift
│       ├── CategoryFilterButton.swift
│       └── EmptyStateView.swift
└── Managers/
    └── NotificationManager.swift  # Notification handling

CatchupWidget/
├── CatchupWidget.swift       # Widget implementation
└── Info.plist               # Widget configuration
```

## Data Models

### Contact
- Name, phone number, email
- Category (Personal, Work, Family, Friends)
- Check-in frequency (in days)
- Last check-in date
- Notes and favorites
- Relationship to check-ins (one-to-many)

### CheckIn
- Date and time
- Type (general, call, text, meeting, video, email)
- Notes
- Relationship to contact

## Getting Started

1. **Open in Xcode**: Open `Catchup.xcodeproj` in Xcode 15 or later
2. **Set Development Team**: Select your development team in project settings
3. **Build & Run**: Select a simulator or device and run (⌘R)

## Usage

1. **Add Contacts**: Tap the + button to add people you want to stay connected with
2. **Set Frequency**: Choose how often you want to check in (weekly, monthly, etc.)
3. **Record Check-ins**: When you connect with someone, record it with optional notes
4. **Stay on Track**: Get reminders when it's time to reach out
5. **Review History**: View all past interactions in the journal

## Widget Setup

1. Long press on home screen
2. Tap the + button
3. Search for "Catchup"
4. Choose a size (small, medium, or large)
5. Add to home screen

## Permissions

- **Notifications**: To send reminders when it's time to check in
- **Contacts** (Optional): Not currently used but reserved for future features

## Data Privacy

- All data is stored locally on your device using SwiftData
- No data is sent to external servers
- Export your data anytime from Settings

## Future Enhancements

- iCloud sync across devices
- Import contacts from system Contacts app
- Advanced analytics and insights
- Group contacts
- Custom frequency intervals
- Contact photos
- Calendar integration
- Siri shortcuts
- Dark mode customization

## License

This project is open source and available for educational purposes.

## Credits

Inspired by the Catchup app by Chris Lee. Built as an open-source alternative with enhanced features.

