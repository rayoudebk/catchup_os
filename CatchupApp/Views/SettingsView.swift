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
                
                ForEach(categoryManager.enabledCategories, id: \.self) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text(category.rawValue)
                        
                        Spacer()
                        
                        if category == .personal {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Button(role: .destructive) {
                                deleteCategory(category)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    categoryManager.reorderCategories(from: source, to: destination)
                }
                
                if categoryManager.enabledCategories.count + customCategories.count < 6 {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }
            .onChange(of: categoryManager.refreshTrigger) { _, _ in
                // Trigger view refresh
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(
                    newCategoryName: $newCategoryName,
                    newCategoryEmoji: $newCategoryEmoji,
                    onSave: {
                        addCustomCategory()
                        showingAddCategory = false
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
                "category": contact.category.rawValue,
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
            if contact.category == category {
                contact.category = .personal
            }
        }
        
        // Disable the category so it doesn't show in UI - this triggers refresh
        categoryManager.disableCategory(category)
    }
    
    private func addCustomCategory() {
        let maxOrder = customCategories.map { $0.order }.max() ?? -1
        let category = CustomCategory(
            name: newCategoryName,
            emoji: newCategoryEmoji,
            icon: "folder.fill",
            order: maxOrder + 1
        )
        modelContext.insert(category)
        
        // Add to category order
        var order = categoryManager.categoryOrder
        order.append(newCategoryName)
        categoryManager.categoryOrder = order
        
        newCategoryName = ""
        newCategoryEmoji = "📁"
    }
}

struct AddCategorySheet: View {
    @Binding var newCategoryName: String
    @Binding var newCategoryEmoji: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $newCategoryName)
                    TextField("Emoji", text: $newCategoryEmoji)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newCategoryName = ""
                        newCategoryEmoji = "📁"
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave()
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
        }
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

