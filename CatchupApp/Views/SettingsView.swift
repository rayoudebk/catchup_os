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
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = "📁"
    
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
        
        // Add built-in categories
        let enabledBuiltIn = categoryManager.enabledCategories
        let order = categoryManager.categoryOrder
        
        for category in enabledBuiltIn {
            let orderIndex = order.firstIndex(of: category.rawValue) ?? Int.max
            items.append(CategoryItem(
                id: category.rawValue,
                name: category.rawValue,
                icon: category.icon,
                emoji: "",
                isLocked: category == .personal,
                builtInCategory: category,
                customCategory: nil,
                order: orderIndex
            ))
        }
        
        // Add custom categories
        for customCat in customCategories {
            items.append(CategoryItem(
                id: customCat.id.uuidString,
                name: customCat.name,
                icon: customCat.icon,
                emoji: customCat.emoji,
                isLocked: false,
                builtInCategory: nil,
                customCategory: customCat,
                order: customCat.order + 1000 // Place after built-in
            ))
        }
        
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
            
            Section("Categories") {
                Text("Maximum 6 categories total. Personal category cannot be deleted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(allCategories, id: \.id) { categoryItem in
                    HStack {
                        // Drag handle
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        if let customCat = categoryItem.customCategory {
                            Text(customCat.emoji)
                                .font(.title3)
                                .frame(width: 24)
                        } else {
                            Image(systemName: categoryItem.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                        }
                        
                        Text(categoryItem.name)
                        
                        Spacer()
                        
                        if categoryItem.isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
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
                
                if allCategories.count < 6 {
                    Button {
                        // Reset state synchronously before showing sheet
                        newCategoryName = ""
                        newCategoryEmoji = ""
                        showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(
                    newCategoryName: $newCategoryName,
                    newCategoryEmoji: $newCategoryEmoji,
                    onSave: {
                        addCustomCategory()
                        // Reset state after save
                        newCategoryName = ""
                        newCategoryEmoji = ""
                    },
                    onDismiss: {
                        // Reset state when sheet is dismissed
                        newCategoryName = ""
                        newCategoryEmoji = ""
                    }
                )
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
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
        let maxOrder = customCategories.map { $0.order }.max() ?? (categoryManager.enabledCategories.count - 1)
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
        var reordered = allCategories
        reordered.move(fromOffsets: source, toOffset: destination)
        
        // Update order for built-in categories
        var builtInOrder: [String] = []
        
        for (index, item) in reordered.enumerated() {
            if let builtIn = item.builtInCategory {
                builtInOrder.append(builtIn.rawValue)
            } else if let custom = item.customCategory {
                // Update custom category order
                custom.order = index
            }
        }
        
        // Update built-in category order
        categoryManager.categoryOrder = builtInOrder
        
        // Save custom category orders
        do {
            try modelContext.save()
        } catch {
            print("Error saving category order: \(error)")
        }
        
        // Trigger refresh
        categoryManager.refreshTrigger = UUID()
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
                            showingEmojiPicker = true
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
        .interactiveDismissDisabled(false)
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




