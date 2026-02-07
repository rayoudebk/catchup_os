# Contact+Notes (iOS)

Contact+Notes is a private, offline-first iOS app for keeping notes organized by person.

The product is intentionally simple:
- keep people in one list,
- keep a timeline of notes per person,
- keep birthdays and gift ideas,
- optionally dictate notes with on-device transcription,
- export data when you choose.

## Current Product Scope

### Core Features
- **Contacts + Notes Timeline**: Each contact has a chronological note timeline.
- **Social Circles**: Organize contacts by fixed circles: `Personal`, `Family`, `Friends`, `Work`, `Other`.
- **Birthday Support**: Store birthdays and birthday notes.
- **Gift Ideas**: Keep one gift idea field per contact.
- **Birthday-Only Reminders**: Annual local notification reminders (9:00 AM local time).
- **On-Device Voice Notes**: Record audio and transcribe locally.
- **Export Options**:
  - JSON export for backup/interoperability
  - Human-readable export via share sheet (works well with Apple Notes)
- **Clear Data**: Explicit local data wipe from Settings.

### Privacy + Storage
- **On-device only** storage (SwiftData local store).
- **No cloud backend**.
- **No iCloud sync** in the current version.
- Local file protection is applied for sensitive app-managed files.

## Technical Stack

- **SwiftUI** for UI
- **SwiftData** for persistence
- **UserNotifications** for birthday reminders
- **Contacts.framework** for importing from iOS Contacts
- **Speech + local model management** for on-device transcription flow

## Project Structure

```text
CatchupApp/
├── CatchupApp.swift
├── ContentView.swift
├── Info.plist
├── Models/
│   ├── Contact.swift
│   └── CheckIn.swift            # contains ContactNote + legacy CheckIn migration model
├── Managers/
│   ├── CategoryManager.swift
│   ├── NotificationManager.swift
│   └── WhisperTranscriptionManager.swift
└── Views/
    ├── AddContactView.swift
    ├── ContactDetailView.swift
    ├── EditContactView.swift
    ├── SettingsView.swift
    └── Components/
        ├── ContactRowView.swift
        └── EmptyStateView.swift
```

## Data Model (Current)

### Contact
- identity: name, phone, email
- social circle
- birthday + birthday note
- gift idea
- favorite flag
- profile image data (optional)
- relationship to notes

### ContactNote
- created/updated timestamps
- note body
- source (`typed`, `voice`, `migratedLegacy`)
- optional transcription metadata
- relationship to contact

### Legacy Migration
- Old `CheckIn` records are migrated into `ContactNote` timeline entries.
- Legacy plain-text note fields are migrated once, then cleared.

## Getting Started

1. Open `/Users/rayaneachich/Desktop/catchup_os/catchup_os.xcodeproj` in Xcode.
2. Select the `catchup_os` scheme and your team signing settings.
3. Build and run on a device or simulator.

## CI and Release Automation

GitHub Actions workflows in this repository:

1. `.github/workflows/ios-ci.yml`
   1. Runs on pull requests and pushes to `main`
   2. Resolves packages and builds the app for iOS Simulator with signing disabled
2. `.github/workflows/xcode-analyze.yml`
   1. Runs on pull requests and pushes to `main`
   2. Executes `xcodebuild analyze` for static analysis checks
3. `.github/workflows/testflight-release.yml`
   1. Manual trigger only (`workflow_dispatch`)
   2. Archives, exports IPA, and uploads to TestFlight
   3. Does not run on PR or push

### Required GitHub Secrets (TestFlight workflow)

1. `IOS_DIST_CERT_P12_BASE64`
2. `IOS_DIST_CERT_PASSWORD`
3. `IOS_PROVISION_PROFILE_BASE64`
4. `IOS_PROVISION_PROFILE_SPECIFIER`
5. `APPSTORE_CONNECT_API_KEY_ID`
6. `APPSTORE_CONNECT_ISSUER_ID`
7. `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64`

### Optional GitHub Variables

1. `APP_BUNDLE_ID` (defaults to `rayoudev.catchup`)
2. `DEVELOPMENT_TEAM_ID` (defaults to `Q25X2WD6VV`)

### Branch Protection Recommendation

For `main`, require status checks:

1. `ios-ci`
2. `xcode-analyze`

Do not require `testflight-release` for merge, since it is manual by design.

## Permissions

- **Contacts**: optional import from iOS address book
- **Microphone**: voice note recording
- **Speech Recognition**: local transcription
- **Notifications**: birthday reminders only

## Export to Apple Notes

In Settings:
1. Tap **Export to Apple Notes**.
2. In the iOS share sheet, choose **Notes**.
3. Save as a new or existing note.

The exported format is intended to be readable for non-technical users.

## Non-Goals (Current Version)

- No check-in frequency system
- No check-in type taxonomy
- No home screen widget
- No photo-memory linking feature
- No cloud/iCloud sync

## License

This repository is available for educational and product development use.
