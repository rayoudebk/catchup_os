import SwiftUI
import SwiftData

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @ObservedObject private var categoryManager = CategoryManager.shared
    @Bindable var contact: Contact
    @State private var showingCategoryPicker = false
    
    let frequencyOptions = [7, 30, 90, 365]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Detail") {
                    TextField("Name", text: $contact.name)
                    
                    TextField("Phone Number", text: Binding(
                        get: { contact.phoneNumber ?? "" },
                        set: { contact.phoneNumber = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                    
                    TextField("Email", text: Binding(
                        get: { contact.email ?? "" },
                        set: { contact.email = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                }
                
                Section("Contact Type") {
                    Toggle(isOn: $contact.isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                    }
                    
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack {
                            Text("Category")
                            
                            Spacer()
                            
                            // Display current selection
                            if let customId = contact.customCategoryId,
                               let custom = customCategories.first(where: { $0.id == customId }) {
                                HStack(spacing: 4) {
                                    Text(custom.emoji)
                                    Text(custom.name)
                                        .foregroundColor(.blue)
                                }
                            } else if let builtIn = ContactCategory(rawValue: contact.categoryIdentifier) {
                                HStack(spacing: 4) {
                                    Image(systemName: builtIn.icon)
                                        .foregroundColor(.blue)
                                        .font(.subheadline)
                                    Text(builtIn.rawValue)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .sheet(isPresented: $showingCategoryPicker) {
                        CategoryPickerSheet(
                            contact: contact,
                            customCategories: customCategories,
                            categoryManager: categoryManager
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                    HStack {
                            Text("We met...")
                                .foregroundColor(.secondary)
                            Spacer()
                            TextField("How did you meet?", text: Binding(
                                get: { contact.weMet },
                                set: { 
                                    let limited = String($0.prefix(50))
                                    contact.weMet = ensureLowercaseFirst(limited)
                                }
                            ))
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: contact.weMet) { _, newValue in
                                if newValue.count > 50 {
                                    contact.weMet = ensureLowercaseFirst(String(newValue.prefix(50)))
                                } else {
                                    contact.weMet = ensureLowercaseFirst(newValue)
                                }
                            }
                        }
                        
                        Text("e.g., \"during XYZ conference\", \"at ABC school\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Check-in Settings") {
                    Picker("Check in every", selection: $contact.frequencyDays) {
                        ForEach(frequencyOptions, id: \.self) { days in
                            Text("\(frequencyLabel(for: days))")
                                .tag(days)
                        }
                    }
                    
                    Picker("Preferred Day", selection: Binding(
                        get: { contact.preferredDayOfWeek ?? 0 },
                        set: { contact.preferredDayOfWeek = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Any Day").tag(0)
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Preferred Time", selection: Binding(
                        get: { contact.preferredHour ?? -1 },
                        set: { contact.preferredHour = $0 == -1 ? nil : $0 }
                    )) {
                        Text("Any Time").tag(-1)
                        ForEach(0..<24) { hour in
                            Text(timeString(for: hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("You'll be reminded to reach out every \(frequencyLabel(for: contact.frequencyDays).lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Reschedule notification with new frequency
                        NotificationManager.shared.scheduleNotification(for: contact)
                        dismiss()
                    }
                    .disabled(contact.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func ensureLowercaseFirst(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let firstChar = text.prefix(1).lowercased()
        let rest = text.dropFirst()
        return firstChar + rest
    }
    
    private func frequencyLabel(for days: Int) -> String {
        switch days {
        case 7: return "Weekly"
        case 30: return "Monthly"
        case 90: return "Quarterly"
        case 365: return "Yearly"
        default: return "\(days) Days"
        }
    }
    
    private func timeString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        if let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

struct CategoryPickerSheet: View {
    @Bindable var contact: Contact
    let customCategories: [CustomCategory]
    let categoryManager: CategoryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Built-in categories
                ForEach(categoryManager.enabledCategories, id: \.self) { cat in
                    Button {
                        contact.categoryIdentifier = cat.rawValue
                        contact.customCategoryId = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(cat.rawValue)
                                .foregroundColor(.blue)
                            Spacer()
                            if contact.categoryIdentifier == cat.rawValue && contact.customCategoryId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Custom categories
                ForEach(customCategories, id: \.id) { customCat in
                    Button {
                        contact.categoryIdentifier = customCat.name
                        contact.customCategoryId = customCat.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(customCat.emoji)
                                .frame(width: 24, alignment: .leading)
                            Text(customCat.name)
                                .foregroundColor(.blue)
                            Spacer()
                            if contact.customCategoryId == customCat.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

