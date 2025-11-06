# Catchup - Architecture Documentation

## Overview

Catchup is built using modern iOS development practices with SwiftUI, SwiftData, and follows the MVVM (Model-View-ViewModel) architecture pattern.

## Technology Stack

### Core Frameworks
- **SwiftUI**: Declarative UI framework for all views
- **SwiftData**: Apple's new data persistence framework (iOS 16+)
- **WidgetKit**: Home screen widgets
- **UserNotifications**: Local notification system
- **Combine**: Reactive programming (implicit through SwiftUI)

### Minimum Requirements
- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture Pattern

### MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────┐
│                   View Layer                 │
│  (SwiftUI Views - Declarative UI)           │
│  - ContentView                               │
│  - ContactDetailView                         │
│  - AddContactView, etc.                      │
└─────────────┬───────────────────────────────┘
              │
              │ @Bindable, @Query
              │ Environment injection
              │
┌─────────────▼───────────────────────────────┐
│              ViewModel Layer                 │
│  (Implicit via SwiftUI @State/@Bindable)    │
│  - UI state management                       │
│  - User interaction handling                 │
└─────────────┬───────────────────────────────┘
              │
              │ SwiftData queries
              │ Model updates
              │
┌─────────────▼───────────────────────────────┐
│               Model Layer                    │
│  (SwiftData Models + Business Logic)        │
│  - Contact (@Model)                          │
│  - CheckIn (@Model)                          │
│  - Computed properties (daysUntilNextCheckIn)│
└─────────────┬───────────────────────────────┘
              │
              │ Persistence
              │
┌─────────────▼───────────────────────────────┐
│            Data Layer                        │
│  (SwiftData Container)                       │
│  - Local SQLite database                     │
│  - Automatic schema management               │
└─────────────────────────────────────────────┘
```

## Data Flow

### 1. Data Persistence (SwiftData)

```swift
@main
struct CatchupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Contact.self, CheckIn.self])
    }
}
```

**How it works:**
- SwiftData automatically creates and manages the database
- `@Model` macro transforms classes into database entities
- `@Query` property wrapper fetches and observes data
- Changes are automatically persisted

### 2. View Updates (Reactive)

```swift
@Query(sort: \Contact.name) private var contacts: [Contact]
```

**Flow:**
1. View declares data dependency with `@Query`
2. SwiftData monitors changes to the data
3. When data changes, view automatically re-renders
4. No manual refresh needed

### 3. User Interactions

```
User Action
    ↓
View captures event (Button, onTapGesture, etc.)
    ↓
Update @State or @Bindable property
    ↓
SwiftUI triggers view update
    ↓
Changes persist via modelContext.insert/delete
    ↓
@Query automatically reflects changes
    ↓
UI updates
```

## Core Components

### Models (`@Model`)

#### Contact
```swift
@Model
final class Contact {
    var id: UUID
    var name: String
    var category: ContactCategory
    var frequencyDays: Int
    var lastCheckInDate: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \CheckIn.contact)
    var checkIns: [CheckIn]?
    
    // Computed properties
    var daysUntilNextCheckIn: Int { ... }
    var isOverdue: Bool { ... }
}
```

**Responsibilities:**
- Store contact information
- Calculate check-in status
- Manage relationship with check-ins
- Business logic for reminder timing

#### CheckIn
```swift
@Model
final class CheckIn {
    var id: UUID
    var date: Date
    var note: String
    var checkInType: CheckInType
    var contact: Contact?
}
```

**Responsibilities:**
- Record interaction details
- Link to parent contact
- Store notes and metadata

### Views (SwiftUI)

#### ContentView (Main List)
```
ContentView
├── StatsHeaderView (metrics)
├── CategoryFilterButton (filters)
└── List
    └── ContactRowView (for each contact)
        └── NavigationLink → ContactDetailView
```

**Responsibilities:**
- Display all contacts
- Search and filter
- Sort options
- Navigation to details

#### ContactDetailView
```
ContactDetailView
├── Header (avatar, name, status)
├── QuickActionButtons (call, text, email)
├── InfoRows (contact details)
└── CheckInHistory
    └── CheckInRowView (for each check-in)
```

**Responsibilities:**
- Show contact details
- Display check-in history
- Enable quick actions
- Edit/delete contact

### Managers (Services)

#### NotificationManager
```swift
class NotificationManager {
    static let shared = NotificationManager()
    
    func scheduleNotification(for contact: Contact)
    func cancelNotification(for contact: Contact)
    func requestAuthorization()
}
```

**Responsibilities:**
- Request notification permissions
- Schedule reminders based on check-in frequency
- Cancel outdated notifications
- Handle notification delivery

## Data Relationships

### One-to-Many: Contact ↔ CheckIns

```
Contact (1)
    └── CheckIns (Many)
        ├── CheckIn 1
        ├── CheckIn 2
        └── CheckIn N
```

**Cascade Delete:**
When a contact is deleted, all associated check-ins are automatically removed.

```swift
@Relationship(deleteRule: .cascade, inverse: \CheckIn.contact)
var checkIns: [CheckIn]?
```

## State Management

### Local State (`@State`)
Used for temporary UI state that doesn't persist:
- Sheet presentation (`showingAddContact`)
- Alert visibility (`showingDeleteAlert`)
- Search text (`searchText`)
- Selected filters (`selectedCategory`)

### Bindable State (`@Bindable`)
Used for editing existing model objects:
```swift
@Bindable var contact: Contact
```
Changes are immediately persisted to SwiftData.

### Environment State (`@Environment`)
Access shared environment values:
```swift
@Environment(\.modelContext) private var modelContext
@Environment(\.dismiss) private var dismiss
```

## Widget Architecture

### Timeline Provider

```
Widget Request
    ↓
Provider.getTimeline()
    ↓
Fetch data from shared container
    ↓
Create timeline entries
    ↓
WidgetKit renders entry
```

**Update Strategy:**
- System-controlled updates (battery-efficient)
- Updates when app is active
- Can be forced via `WidgetCenter.shared.reloadAllTimelines()`

### Widget Sizes

1. **Small**: Shows overdue count or "all caught up"
2. **Medium**: Shows overdue and upcoming stats
3. **Large**: Shows list of overdue and upcoming contacts

## Notification Flow

```
User adds/updates contact
    ↓
NotificationManager.scheduleNotification()
    ↓
Calculate next check-in date
    ↓
Create UNNotificationRequest
    ↓
Schedule with UNUserNotificationCenter
    ↓
System delivers notification at scheduled time
    ↓
User taps notification → Opens app
```

## Data Export Architecture

```
User requests export
    ↓
Fetch all contacts and check-ins
    ↓
Serialize to JSON with metadata
    ↓
Create exportable string
    ↓
Show ShareSheet with file
```

**Export Format:**
```json
{
  "contacts": [...],
  "checkIns": [...],
  "exportDate": "2024-11-05T12:00:00Z",
  "version": "1.0.0"
}
```

## Performance Considerations

### SwiftData Optimizations

1. **Lazy Loading**: Relationships are loaded on-demand
2. **Batch Fetching**: SwiftData optimizes query execution
3. **Automatic Caching**: Frequently accessed objects are cached
4. **Background Context**: Heavy operations can use background contexts

### Query Optimization

```swift
// Efficient: Sorted at database level
@Query(sort: \Contact.name) private var contacts: [Contact]

// Less efficient: Sorting in memory
var sortedContacts: [Contact] {
    contacts.sorted { $0.name < $1.name }
}
```

### View Performance

1. **List Optimization**: SwiftUI only renders visible rows
2. **Computed Properties**: Cached by SwiftUI when dependencies don't change
3. **Lazy Stacks**: Use `LazyVStack`/`LazyHStack` for large lists

## Security & Privacy

### Data Storage
- All data stored locally in app sandbox
- No network requests
- No third-party SDKs
- No analytics or tracking

### Permissions
- **Notifications**: Required for reminders
- **Contacts** (future): Optional for contact import

### Data Access
- SwiftData uses encrypted storage on device
- App-sandboxed (isolated from other apps)
- Backed up via iCloud (if user enabled)

## Testing Strategy

### Unit Testing
- Test model logic (calculated properties)
- Test date calculations
- Test category/frequency enums

### UI Testing
- Test navigation flows
- Test CRUD operations
- Test search and filter

### Widget Testing
- Test different timeline scenarios
- Test empty states
- Test all widget sizes

## Future Architecture Improvements

### 1. iCloud Sync
```
SwiftData Container
    └── .iCloud configuration
        └── Automatic sync across devices
```

### 2. MVVM with Explicit ViewModels
```swift
class ContactListViewModel: ObservableObject {
    @Published var contacts: [Contact]
    @Published var searchText: String
    
    func loadContacts() { ... }
    func addContact(_ contact: Contact) { ... }
}
```

### 3. Dependency Injection
```swift
protocol NotificationService {
    func schedule(for contact: Contact)
}

struct ContentView: View {
    let notificationService: NotificationService
}
```

### 4. Repository Pattern
```swift
protocol ContactRepository {
    func fetchAll() -> [Contact]
    func save(_ contact: Contact)
    func delete(_ contact: Contact)
}
```

## Code Organization Best Practices

1. **Separation of Concerns**: Each file has one responsibility
2. **View Components**: Reusable UI components in `Components/`
3. **Models**: Pure data models with minimal logic
4. **Managers**: Shared services (notifications, etc.)
5. **Extensions**: Keep in separate files per type

## Debugging Tips

### SwiftData Issues
```swift
// Enable SQL logging
let container = try ModelContainer(
    for: Contact.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: false)
)
```

### View Updates Not Working
- Check `@Query` is used correctly
- Ensure model changes are on main thread
- Verify `@Bindable` for edit forms

### Widget Not Updating
- Check shared app group is configured
- Verify widget has access to SwiftData container
- Force reload: `WidgetCenter.shared.reloadAllTimelines()`

---

This architecture provides a solid foundation that's:
- ✅ Scalable
- ✅ Maintainable
- ✅ Testable
- ✅ Modern (Swift 5.9+)
- ✅ Performant

