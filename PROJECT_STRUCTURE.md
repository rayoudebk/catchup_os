# Project Structure

## Overview
This document explains the project structure to avoid confusion between folders.

## Key Folders

### `catchup_os/` (Auto-synced)
- **Purpose**: Contains assets and files that Xcode automatically syncs
- **Contents**:
  - `Assets.xcassets/` - **THE ONLY ASSET CATALOG USED BY THE PROJECT**
    - `AppIcon.appiconset/` - App icons (120x120, 152x152, 1024x1024)
    - `AccentColor.colorset/` - App accent color
- **Note**: This folder uses `PBXFileSystemSynchronizedRootGroup`, meaning Xcode automatically includes all files

### `CatchupApp/` (Manually managed)
- **Purpose**: Contains all application source code
- **Contents**:
  - `CatchupApp.swift` - App entry point
  - `ContentView.swift` - Main view
  - `Info.plist` - App configuration
  - `Managers/` - Business logic managers
  - `Models/` - Data models (Contact, CheckIn, CustomCategory)
  - `Views/` - All SwiftUI views
    - `Components/` - Reusable UI components
- **Note**: This folder is manually managed in the Xcode project

### `CatchupWidget/`
- **Purpose**: Widget extension (if used)
- **Contents**: Widget-specific code

## Important Rules

1. **Assets go in `catchup_os/Assets.xcassets`** - This is the ONLY asset catalog used
2. **Code goes in `CatchupApp/`** - All Swift files belong here
3. **Never create duplicate asset catalogs** - Only use `catchup_os/Assets.xcassets`
4. **When adding assets**: Always add to `catchup_os/Assets.xcassets`, NOT `CatchupApp/`

## Why This Structure?

- `catchup_os/` uses file system synchronization for easy asset management
- `CatchupApp/` uses manual file references for precise code organization
- This separation prevents conflicts and makes it clear where things belong

## Common Mistakes to Avoid

❌ **DON'T**: Create `CatchupApp/Assets.xcassets` (duplicate)
❌ **DON'T**: Put code files in `catchup_os/` folder
✅ **DO**: Put assets in `catchup_os/Assets.xcassets`
✅ **DO**: Put code in `CatchupApp/`



