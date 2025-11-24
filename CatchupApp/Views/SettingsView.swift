import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [Contact]
    @Query private var checkIns: [CheckIn]
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    
    @ObservedObject private var categoryManager = CategoryManager.shared
    @State private var notificationsEnabled = true
    @State private var showingExportAlert = false
    @State private var showingClearDataAlert = false
    @State private var exportData = ""
    @State private var showingShareSheet = false
    @State private var showingAddCategory = false
    @State private var showingBulkFrequencyEdit = false
    @State private var showingBulkCategoryEdit = false
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = ""
    @State private var editMode: EditMode = .active
    
    struct CategoryItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let emoji: String
        let isLocked: Bool
        let builtInCategory: ContactCategory?
        let customCategory: CustomCategory?
        let order: Int
    }
    
    var allCategories: [CategoryItem] {
        var items: [CategoryItem] = []
        
        // Add built-in categories with their order values
        let enabledBuiltIn = categoryManager.enabledCategories
        
        for category in enabledBuiltIn {
            let order = categoryManager.getOrder(for: category)
            items.append(CategoryItem(
                id: category.rawValue,
                name: category.rawValue,
                icon: category.icon,
                emoji: "",
                isLocked: category == .personal,
                builtInCategory: category,
                customCategory: nil,
                order: order
            ))
        }
        
        // Add custom categories with their order values
        for customCat in customCategories {
            items.append(CategoryItem(
                id: customCat.id.uuidString,
                name: customCat.name,
                icon: customCat.icon,
                emoji: customCat.emoji,
                isLocked: false,
                builtInCategory: nil,
                customCategory: customCat,
                order: customCat.order
            ))
        }
        
        // Sort by order - this allows true interleaving!
        return items.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Contacts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(contacts.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Check-ins")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(checkIns.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Support Me!") {
                Button {
                    if let url = URL(string: "https://forms.gle/2hMux5XCh9Q4xzdd7") {
                        openInSafari(url: url)
                    }
                } label: {
                    HStack {
                        Text("Send your feedback")
                        Spacer()
                        Text("💡")
                            .font(.title3)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    shareApp()
                } label: {
                    HStack {
                        Text("Share this app with friends")
                        Spacer()
                        Text("📬")
                            .font(.title3)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Notifications") {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Reminders")
                        Text("Get notified when it's time to check in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEnabled) { _, newValue in
                    if newValue {
                        NotificationManager.shared.requestAuthorization()
                    }
                }
                
                Button {
                    openNotificationSettings()
                } label: {
                    HStack {
                        Text("Notification Settings")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Contact Management") {
                Button {
                    showingBulkFrequencyEdit = true
                } label: {
                    HStack {
                        Text("Bulk Frequency Edit")
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    showingBulkCategoryEdit = true
                } label: {
                    HStack {
                        Text("Bulk Category Edit")
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Categories") {
                Text("Maximum 6 categories total. Personal category cannot be deleted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(allCategories, id: \.id) { categoryItem in
                    HStack {
                        if let customCat = categoryItem.customCategory {
                            Text(customCat.emoji)
                                .font(.title3)
                                .frame(width: 24)
                        } else {
                            Image(systemName: categoryItem.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                        }
                        
                        HStack(spacing: 4) {
                            Text(categoryItem.name)
                            
                            if categoryItem.isLocked {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        // Drag handle on the right
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !categoryItem.isLocked {
                            Button(role: .destructive) {
                                if let customCat = categoryItem.customCategory {
                                    deleteCustomCategory(customCat)
                                } else if let builtInCategory = categoryItem.builtInCategory {
                                    deleteCategory(builtInCategory)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .onMove(perform: reorderAllCategories)
                .environment(\.editMode, $editMode)
                
                if allCategories.count < 6 {
                    Button {
                        // Reset state first
                        newCategoryName = ""
                        newCategoryEmoji = ""
                        // Disable edit mode first, then present sheet after ensuring edit mode is inactive
                        editMode = .inactive
                        // Use Task to ensure edit mode change is processed before presenting
                        Task { @MainActor in
                            // Small delay to ensure edit mode transition completes
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                            showingAddCategory = true
                        }
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: {
                // Re-enable edit mode when sheet is dismissed
                editMode = .active
                // Reset state
                newCategoryName = ""
                newCategoryEmoji = ""
            }) {
                AddCategorySheet(
                    newCategoryName: $newCategoryName,
                    newCategoryEmoji: $newCategoryEmoji,
                    onSave: {
                        addCustomCategory()
                    },
                    onDismiss: {
                        // Empty - parent sheet's onDismiss handles cleanup
                    }
                )
            }
            .sheet(isPresented: $showingBulkFrequencyEdit) {
                BulkFrequencyEditView()
            }
            .sheet(isPresented: $showingBulkCategoryEdit) {
                BulkCategoryEditView()
            }
            
            Section("Data Management") {
                Button {
                    exportDataToJSON()
                } label: {
                    Label("Export Data (json file)", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    showingClearDataAlert = true
                } label: {
                    Label("Clear All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Catchup Team")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Use Catchup")
                        .font(.headline)
                    
                    Text("1. Add contacts you want to stay connected with")
                    Text("2. Set how often you'd like to check in")
                    Text("3. Record check-ins with notes")
                    Text("4. Get gentle reminders when it's time to reach out")
                    
                    Text("Keep your relationships strong, one connection at a time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Settings")
        .alert("Export Data", isPresented: $showingExportAlert) {
            Button("Share") {
                showingShareSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your data has been prepared for export. Would you like to share it?")
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("Are you sure you want to delete all contacts and check-ins? This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportData])
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openInSafari(url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func shareApp() {
        let items: [Any] = ["Help your relationships thrive with Catchup!", URL(string: "https://apps.apple.com/app/id0000000000")!]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
    
    private func exportDataToJSON() {
        var exportDict: [String: Any] = [:]
        
        // Export contacts
        let contactsData = contacts.map { contact in
            [
                "id": contact.id.uuidString,
                "name": contact.name,
                "phoneNumber": contact.phoneNumber ?? "",
                "email": contact.email ?? "",
                "category": contact.categoryIdentifier,
                "customCategoryId": contact.customCategoryId?.uuidString ?? "",
                "frequencyDays": contact.frequencyDays,
                "lastCheckInDate": contact.lastCheckInDate?.ISO8601Format() ?? "",
                "notes": contact.notes,
                "isFavorite": contact.isFavorite,
                "createdAt": contact.createdAt.ISO8601Format()
            ] as [String : Any]
        }
        
        // Export check-ins
        let checkInsData = checkIns.map { checkIn in
            [
                "id": checkIn.id.uuidString,
                "date": checkIn.date.ISO8601Format(),
                "note": checkIn.note,
                "title": checkIn.title,
                "contactId": checkIn.contact?.id.uuidString ?? ""
            ] as [String : Any]
        }
        
        exportDict["contacts"] = contactsData
        exportDict["checkIns"] = checkInsData
        exportDict["exportDate"] = Date().ISO8601Format()
        exportDict["version"] = "1.0.0"
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            exportData = jsonString
            showingExportAlert = true
        }
    }
    
    private func clearAllData() {
        // Delete all check-ins
        for checkIn in checkIns {
            modelContext.delete(checkIn)
        }
        
        // Delete all contacts
        for contact in contacts {
            modelContext.delete(contact)
        }
        
        // Cancel all notifications
        NotificationManager.shared.cancelAllNotifications()
    }
    
    private func deleteCategory(_ category: ContactCategory) {
        // Find all contacts with this category and change them to Personal
        for contact in contacts {
            if contact.categoryIdentifier == category.rawValue && contact.customCategoryId == nil {
                contact.categoryIdentifier = ContactCategory.personal.rawValue
                contact.customCategoryId = nil
            }
        }
        
        // Disable the category so it doesn't show in UI - this triggers refresh
        categoryManager.disableCategory(category)
    }
    
    private func addCustomCategory() {
        // Find the maximum order value among all categories (built-in + custom)
        let maxBuiltInOrder = categoryManager.enabledCategories.map { categoryManager.getOrder(for: $0) }.max() ?? -1
        let maxCustomOrder = customCategories.map { $0.order }.max() ?? -1
        let maxOrder = max(maxBuiltInOrder, maxCustomOrder)
        
        let category = CustomCategory(
            name: newCategoryName,
            emoji: newCategoryEmoji,
            icon: "folder.fill",
            order: maxOrder + 1
        )
        modelContext.insert(category)
        
        // Save and trigger refresh
        do {
            try modelContext.save()
            categoryManager.refreshTrigger = UUID()
        } catch {
            print("Error saving category: \(error)")
        }
    }
    
    private func deleteCustomCategory(_ category: CustomCategory) {
        // Find all contacts with this custom category and change them to Personal
        for contact in contacts {
            if contact.customCategoryId == category.id {
                contact.categoryIdentifier = ContactCategory.personal.rawValue
                contact.customCategoryId = nil
            }
        }
        
        modelContext.delete(category)
        try? modelContext.save()
        categoryManager.refreshTrigger = UUID()
    }
    
    private func reorderAllCategories(from source: IndexSet, to destination: Int) {
        // Get current categories array
        var reordered = allCategories
        
        // Perform the move operation
        reordered.move(fromOffsets: source, toOffset: destination)
        
        // Now assign sequential order values (0, 1, 2, ...) based on final positions
        // This allows true interleaving of built-in and custom categories
        for (finalPosition, item) in reordered.enumerated() {
            if let builtIn = item.builtInCategory {
                // Update built-in category order
                categoryManager.setOrder(finalPosition, for: builtIn)
            } else if let custom = item.customCategory {
                // Update custom category order
                custom.order = finalPosition
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            // Trigger refresh to update UI
            categoryManager.refreshTrigger = UUID()
        } catch {
            print("Error saving category order: \(error)")
        }
    }
}

struct AddCategorySheet: View {
    @Binding var newCategoryName: String
    @Binding var newCategoryEmoji: String
    let onSave: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var showingEmojiPicker = false
    
    enum Field {
        case name, emoji
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $newCategoryName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                    
                    HStack {
                        // Left side: Display selected emoji (empty initially, no background)
                        if !newCategoryEmoji.isEmpty {
                            Text(newCategoryEmoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        } else {
                            Spacer()
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        // Right side: Blue emoji button (always visible) - Apple keyboard emoji
                        Button {
                            // Defer emoji picker presentation to avoid conflicts
                            DispatchQueue.main.async {
                                showingEmojiPicker = true
                            }
                        } label: {
                            Text("😊")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave()
                        dismiss()
                    }
                    .disabled(newCategoryName.isEmpty || newCategoryEmoji.isEmpty)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerView(selectedEmoji: $newCategoryEmoji)
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(true) // Prevent swipe-to-dismiss, must use Cancel/Add buttons
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    
    let emojiCategories: [(String, [String])] = [
        ("Smileys", ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙"]),
        ("Objects", ["📁", "📂", "📄", "📃", "📑", "📊", "📈", "📉", "🗂️", "📅", "📆", "🗒️", "📋", "📇", "📌", "📍", "📎", "🖇️", "📏", "📐"]),
        ("Symbols", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️"]),
        ("Flags", ["🏳️", "🏴", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🇺🇸", "🇬🇧", "🇫🇷", "🇩🇪", "🇯🇵", "🇨🇳", "🇮🇳", "🇧🇷", "🇷🇺", "🇰🇷", "🇮🇹", "🇪🇸", "🇨🇦", "🇦🇺"])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(emojiCategories, id: \.0) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.0)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                                ForEach(category.1, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 44, height: 44)
                                            .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Bulk frequency edit view - bucket-based UI similar to add contacts
struct BulkFrequencyEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var searchText = ""
    @State private var selectedFrequency: Int? = nil
    @State private var contactFrequencyMap: [UUID: Int] = [:]
    
    let frequencyOptions = [7, 30, 90, 365]
    
    func frequencyLabel(for days: Int) -> String {
        switch days {
        case 7: return "Weekly"
        case 30: return "Monthly"
        case 90: return "Quarterly"
        case 365: return "Yearly"
        default: return "\(days) Days"
        }
    }
    
    // Filter contacts by search
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Get count of contacts with a frequency
    func contactCount(for frequency: Int) -> Int {
        contacts.filter { contactFrequencyMap[$0.id] == frequency }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Frequency selection buttons at the top
                VStack(spacing: 12) {
                    HStack {
                        Text("Set how often you want to catch up")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Frequency buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(frequencyOptions, id: \.self) { frequency in
                                FrequencyBucketButton(
                                    title: frequencyLabel(for: frequency),
                                    isSelected: selectedFrequency == frequency,
                                    count: contactCount(for: frequency)
                                ) {
                                    selectedFrequency = frequency
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
                .background(Color(UIColor.secondarySystemBackground))
                
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Contact list
                if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No contacts to edit")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedFrequency == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Select a frequency above, then tap contacts to assign")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredContacts) { contact in
                            ContactFrequencyAssignmentRow(
                                contact: contact,
                                selectedFrequency: selectedFrequency!,
                                isSelected: contactFrequencyMap[contact.id] == selectedFrequency,
                                onToggle: { isSelected in
                                    if isSelected {
                                        contactFrequencyMap[contact.id] = selectedFrequency!
                                    } else {
                                        contactFrequencyMap.removeValue(forKey: contact.id)
                                    }
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Bulk Frequency Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveFrequencies()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize map with current frequencies
                for contact in contacts {
                    contactFrequencyMap[contact.id] = contact.frequencyDays
                }
            }
        }
    }
    
    private func saveFrequencies() {
        for contact in contacts {
            if let newFrequency = contactFrequencyMap[contact.id], newFrequency != contact.frequencyDays {
                contact.frequencyDays = newFrequency
                // Reschedule notification with new frequency
                NotificationManager.shared.scheduleNotification(for: contact)
            }
        }
    }
}

// Frequency bucket button component
struct FrequencyBucketButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(width: 100, height: 80)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// Contact frequency assignment row
struct ContactFrequencyAssignmentRow: View {
    let contact: Contact
    let selectedFrequency: Int
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                Text(contact.name)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Bulk category edit view - similar to AddCategoryBannerSheetView
struct BulkCategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @ObservedObject private var categoryManager = CategoryManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategoryId: String? // For built-in categories
    @State private var selectedCustomCategoryId: UUID? // For custom categories
    @State private var contactCategoryMap: [UUID: (categoryId: String?, customId: UUID?)] = [:]
    
    // All categories sorted by order (excluding Personal as it's the catch-all)
    var allCategoriesSorted: [CategoryItemForBulk] {
        var items: [CategoryItemForBulk] = []
        
        // Add built-in categories (excluding Personal)
        for category in categoryManager.enabledCategories where category != .personal {
            items.append(CategoryItemForBulk(
                id: category.rawValue,
                builtInCategory: category,
                customCategory: nil,
                order: categoryManager.getOrder(for: category)
            ))
        }
        
        // Add custom categories
        for customCat in customCategories {
            items.append(CategoryItemForBulk(
                id: customCat.id.uuidString,
                builtInCategory: nil,
                customCategory: customCat,
                order: customCat.order
            ))
        }
        
        return items.sorted { $0.order < $1.order }
    }
    
    // Filter contacts by search
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Get count of contacts in a category
    func contactCount(for categoryId: String?, customId: UUID?) -> Int {
        if let customId = customId {
            return contacts.filter { $0.customCategoryId == customId }.count
        } else if let categoryId = categoryId {
            return contacts.filter { $0.categoryIdentifier == categoryId && $0.customCategoryId == nil }.count
        }
        return 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categorySelectionSection
                searchBarSection
                contactListSection
            }
            .navigationTitle("Bulk Category Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveCategories()
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeCategoryMap()
            }
        }
    }
    
    private var categorySelectionSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Set category for your contacts")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                Text("Personal is the default category for contacts without a specific category")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allCategoriesSorted, id: \.id) { categoryItem in
                        categoryButton(for: categoryItem)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    @ViewBuilder
    private func categoryButton(for categoryItem: CategoryItemForBulk) -> some View {
        if let builtIn = categoryItem.builtInCategory {
            CategoryBucketButton(
                title: builtIn.rawValue,
                icon: builtIn.icon,
                emoji: builtIn.emoji,
                isSelected: selectedCategoryId == builtIn.rawValue && selectedCustomCategoryId == nil,
                count: contactCount(for: builtIn.rawValue, customId: nil)
            ) {
                selectedCategoryId = builtIn.rawValue
                selectedCustomCategoryId = nil
            }
        } else if let customCat = categoryItem.customCategory {
            CategoryBucketButton(
                title: customCat.name,
                emoji: customCat.emoji,
                isSelected: selectedCustomCategoryId == customCat.id,
                count: contactCount(for: nil, customId: customCat.id)
            ) {
                selectedCustomCategoryId = customCat.id
                selectedCategoryId = nil
            }
        }
    }
    
    private var searchBarSection: some View {
        SearchBar(text: $searchText)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var contactListSection: some View {
        if contacts.isEmpty {
            emptyContactsView
        } else if selectedCategoryId == nil && selectedCustomCategoryId == nil {
            selectCategoryPromptView
        } else {
            contactListView
        }
    }
    
    private var emptyContactsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No contacts to assign")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var selectCategoryPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Select a category above, then tap contacts to assign")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contactListView: some View {
        List {
            ForEach(filteredContacts) { contact in
                ContactCategoryRow(
                    contact: contact,
                    selectedCategoryId: selectedCategoryId,
                    selectedCustomCategoryId: selectedCustomCategoryId,
                    isSelected: isContactSelected(contact),
                    onToggle: { isSelected in
                        if isSelected {
                            contactCategoryMap[contact.id] = (categoryId: selectedCategoryId, customId: selectedCustomCategoryId)
                        } else {
                            contactCategoryMap.removeValue(forKey: contact.id)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private func isContactSelected(_ contact: Contact) -> Bool {
        guard let categoryInfo = contactCategoryMap[contact.id] else { return false }
        if let selectedCustomId = selectedCustomCategoryId {
            return categoryInfo.customId == selectedCustomId
        } else if let selectedCategoryId = selectedCategoryId {
            return categoryInfo.categoryId == selectedCategoryId && categoryInfo.customId == nil
        }
        return false
    }
    
    private func initializeCategoryMap() {
        for contact in contacts {
            if let customId = contact.customCategoryId {
                contactCategoryMap[contact.id] = (categoryId: contact.categoryIdentifier, customId: customId)
            } else {
                contactCategoryMap[contact.id] = (categoryId: contact.categoryIdentifier, customId: nil)
            }
        }
    }
    
    private func saveCategories() {
        for contact in contacts {
            if let categoryInfo = contactCategoryMap[contact.id] {
                contact.categoryIdentifier = categoryInfo.categoryId ?? ContactCategory.personal.rawValue
                contact.customCategoryId = categoryInfo.customId
            }
        }
    }
}

struct CategoryItemForBulk: Identifiable {
    let id: String
    let builtInCategory: ContactCategory?
    let customCategory: CustomCategory?
    let order: Int
}


