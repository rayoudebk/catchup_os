import SwiftUI
import SwiftData
import Contacts
import ContactsUI
import Foundation

struct AddContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @Query private var existingContacts: [Contact] // To filter out already-added contacts
    @ObservedObject private var categoryManager = CategoryManager.shared
    
    let isFromOnboarding: Bool // Whether this view is opened from onboarding
    
    @State private var searchText = ""
    @State private var allContacts: [CNContact] = []
    @State private var contactFrequencyMap: [String: Int] = [:] // CNContact identifier -> frequency days
    @State private var isLoadingContacts = false
    @State private var selectedFrequency: Int? = 7 // Currently selected frequency for assignment (default to Weekly)
    @State private var showingPermissionHint = false
    
    // Frequency options: Weekly, Monthly, Quarterly, Yearly
    let frequencyOptions = [7, 30, 90, 365]
    
    // Filter out contacts that already exist in the app
    var availableContacts: [CNContact] {
        let existingIdentifiers = Set(existingContacts.compactMap { $0.contactIdentifier })
        let filtered = allContacts.filter { !existingIdentifiers.contains($0.identifier) }
        print("Filtering: \(allContacts.count) total, \(existingIdentifiers.count) existing, \(filtered.count) available")
        return filtered
    }
    
    var filteredContacts: [CNContact] {
        let available = availableContacts
        
        // Filter by search text if provided
        let searchFiltered = searchText.isEmpty ? available : available.filter { contact in
            let name = contactDisplayName(contact)
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Filter: if contact is already assigned to a frequency, only show it if that frequency is selected
        return searchFiltered.filter { contact in
            if let assignedFrequency = contactFrequencyMap[contact.identifier] {
                // Only show if it's assigned to the currently selected frequency
                return assignedFrequency == selectedFrequency
            }
            // If not assigned, show it
            return true
        }
    }
    
    // Categorize contacts for display using scoring system
    var suggestedContacts: [CNContact] {
        let scored = filteredContacts.map { contact in
            (contact: contact, score: calculateContactScore(contact))
        }
        .sorted { $0.score > $1.score }
        .filter { $0.score >= 20 } // Threshold for suggested contacts
        .prefix(100) // Cap at top 100 contacts
        .map { $0.contact }
        
        return Array(scored)
    }
    
    var otherContacts: [CNContact] {
        let suggestedIds = Set(suggestedContacts.map { $0.identifier })
        return filteredContacts.filter { !suggestedIds.contains($0.identifier) }
    }
    
    // Calculate contact score based on available information
    private func calculateContactScore(_ contact: CNContact) -> Int {
        var score = 0
        
        // Positive points
        let hasFirstName = !contact.givenName.isEmpty
        let hasLastName = !contact.familyName.isEmpty
        let hasBothNames = hasFirstName && hasLastName
        let hasNickname = !contact.nickname.isEmpty
        
        // Safely check for photo - use helper function to avoid exceptions
        let hasPhoto = safeHasPhoto(contact)
        
        let hasEmail = !contact.emailAddresses.isEmpty
        let hasOrganization = !contact.organizationName.isEmpty
        
        // Safely check job title - only if key was fetched
        let hasJobTitle: Bool
        if contact.isKeyAvailable(CNContactJobTitleKey) {
            hasJobTitle = !contact.jobTitle.isEmpty
        } else {
            hasJobTitle = false
        }
        
        let hasBirthday = contact.birthday != nil
        let hasAddress = !contact.postalAddresses.isEmpty
        // Note: CNContactNoteKey requires special permission, so we skip note scoring
        let phoneCount = contact.phoneNumbers.count
        let emailCount = contact.emailAddresses.count
        let totalWaysToReach = phoneCount + emailCount
        
        // Scoring
        if hasFirstName { score += 10 }
        if hasLastName { score += 10 }
        if hasBothNames { score += 5 }
        if hasNickname { score += 3 }
        if hasPhoto { score += 8 }
        if hasEmail { score += 8 }
        if hasOrganization { score += 6 }
        if hasJobTitle { score += 3 }
        if hasBirthday { score += 6 }
        if hasAddress { score += 3 }
        // Note scoring removed (requires special permission)
        if totalWaysToReach >= 2 { score += 4 }
        
        // Negative points (likely junk / low priority)
        if !hasFirstName && !hasLastName && !hasOrganization && !hasEmail && phoneCount == 1 {
            score -= 15
        }
        
        return score
    }
    
    // Get contacts that have a frequency selected
    var selectedContacts: [ContactSelection] {
        contactFrequencyMap.compactMap { (identifier, frequencyDays) in
            guard let cnContact = allContacts.first(where: { $0.identifier == identifier }) else { return nil }
            return ContactSelection(
                identifier: identifier,
                cnContact: cnContact,
                frequencyDays: frequencyDays,
                categoryIdentifier: nil,
                customCategoryId: nil
            )
        }
    }
    
    // Get count of contacts for a specific frequency
    func contactCount(for frequency: Int) -> Int {
        contactFrequencyMap.values.filter { $0 == frequency }.count
    }
    
    // Helper function to get frequency label
    func frequencyLabel(for days: Int) -> String {
        switch days {
        case 7: return "Weekly"
        case 30: return "Monthly"
        case 90: return "Quarterly"
        case 365: return "Yearly"
        default: return "\(days) Days"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selectContactsStep
            }
            .navigationTitle("Add Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        importContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .onAppear {
                // Always reload contacts when view appears
                // This handles the case where user grants access and comes back
                let authStatus = CNContactStore.authorizationStatus(for: .contacts)
                if authStatus == .authorized && allContacts.isEmpty {
                    print("View appeared with authorization but no contacts, reloading...")
                }
                loadContacts()
            }
        }
    }
    
    private var selectContactsStep: some View {
        VStack(spacing: 0) {
            // Progress bar (0-5 contacts) - only show during onboarding
            if isFromOnboarding {
                VStack(spacing: 8) {
                    HStack {
                        Text("Add 5 contacts to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(selectedContacts.count)/5")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedContacts.count >= 5 ? .green : .blue)
                    }
                    .padding(.horizontal)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(selectedContacts.count >= 5 ? Color.green : Color.blue)
                                .frame(width: min(CGFloat(selectedContacts.count) / 5.0 * geometry.size.width, geometry.size.width), height: 8)
                                .cornerRadius(4)
                                .animation(.spring(response: 0.3), value: selectedContacts.count)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
            }
            
            // Frequency selection buttons at the top
            VStack(spacing: 12) {
                // Static instruction text
                HStack {
                    Text("Set how often you want to catch up")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Frequency buttons
                HStack(spacing: 12) {
                    ForEach(frequencyOptions, id: \.self) { frequency in
                        FrequencyButton(
                            frequency: frequency,
                            label: frequencyLabel(for: frequency),
                            isSelected: selectedFrequency == frequency,
                            count: contactCount(for: frequency),
                            onTap: {
                                if selectedFrequency == frequency {
                                    selectedFrequency = nil // Deselect
                                } else {
                                    selectedFrequency = frequency
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Contact list - show contacts even without frequency selection for visibility
            if isLoadingContacts {
                ProgressView("Loading contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedFrequency == nil {
                // Show contacts even when no frequency is selected, but with a message
                if filteredContacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Select a frequency above to assign contacts")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Show that contacts are loaded
                        if !allContacts.isEmpty {
                            Text("\(allContacts.count) contacts ready to assign")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show contacts with instruction to select frequency
                    VStack(spacing: 0) {
                        HStack {
                            Text("Select a frequency above, then tap contacts to assign")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        
                        List {
                            // Suggested contacts section
                            if !suggestedContacts.isEmpty {
                                Section("Suggested contacts") {
                                    ForEach(suggestedContacts, id: \.identifier) { cnContact in
                                        HStack {
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary)
                                                .font(.title3)
                                            
                                            Text(contactDisplayName(cnContact))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                            
                            // Other contacts section
                            if !otherContacts.isEmpty {
                                Section("Other contacts") {
                                    ForEach(otherContacts, id: \.identifier) { cnContact in
                                        HStack {
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary)
                                                .font(.title3)
                                            
                                            Text(contactDisplayName(cnContact))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            } else if filteredContacts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No contacts found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Debug info
                    VStack(spacing: 4) {
                        Text("Total loaded: \(allContacts.count)")
                        Text("Available: \(availableContacts.count)")
                        Text("Existing: \(existingContacts.count)")
                        Text("Auth status: \(CNContactStore.authorizationStatus(for: .contacts).rawValue)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    
                    Button("Reload Contacts") {
                        loadContacts()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Suggested contacts section
                    if !suggestedContacts.isEmpty {
                        Section("Suggested contacts") {
                            ForEach(suggestedContacts, id: \.identifier) { cnContact in
                                ContactFrequencyRow(
                                    cnContact: cnContact,
                                    selectedFrequency: selectedFrequency!,
                                    isSelected: contactFrequencyMap[cnContact.identifier] == selectedFrequency,
                                    onToggle: { isSelected in
                                        if isSelected {
                                            contactFrequencyMap[cnContact.identifier] = selectedFrequency!
                                        } else {
                                            contactFrequencyMap.removeValue(forKey: cnContact.identifier)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // Other contacts section
                    if !otherContacts.isEmpty {
                        Section("Other contacts") {
                            ForEach(otherContacts, id: \.identifier) { cnContact in
                                ContactFrequencyRow(
                                    cnContact: cnContact,
                                    selectedFrequency: selectedFrequency!,
                                    isSelected: contactFrequencyMap[cnContact.identifier] == selectedFrequency,
                                    onToggle: { isSelected in
                                        if isSelected {
                                            contactFrequencyMap[cnContact.identifier] = selectedFrequency!
                                        } else {
                                            contactFrequencyMap.removeValue(forKey: cnContact.identifier)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func loadContacts() {
        let store = CNContactStore()
        
        // Check authorization status first
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        print("Current authorization status: \(authStatus.rawValue)")
        
        // If already authorized, load contacts directly
        if authStatus == .authorized {
            print("Already authorized, loading contacts directly...")
            isLoadingContacts = true
            loadContactsFromStore(store)
            return
        }
        
        // If not determined, request access
        if authStatus == .notDetermined {
            print("Authorization not determined, requesting access...")
            isLoadingContacts = true
            store.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    print("Error requesting contacts access: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingContacts = false
                    }
                    return
                }
                
                print("Access granted: \(granted)")
                
                guard granted else {
                    print("Contacts access denied")
                    DispatchQueue.main.async {
                        self.isLoadingContacts = false
                    }
                    return
                }
                
                self.loadContactsFromStore(store)
            }
        } else {
            // Denied or restricted
            print("Contacts access is denied or restricted")
            isLoadingContacts = false
        }
    }
    
    private func loadContactsFromStore(_ store: CNContactStore) {
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactBirthdayKey,
            CNContactPostalAddressesKey,
            // Note: CNContactNoteKey requires special permission, removed to avoid authorization errors
            CNContactImageDataKey,
            CNContactThumbnailImageDataKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        // Don't filter by name - get all contacts
        request.predicate = nil
        
        var contacts: [CNContact] = []
        
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                // Include ALL contacts, even if they don't have names
                // We'll handle display names later
                contacts.append(contact)
            }
            
            print("Loaded \(contacts.count) total contacts from device")
            
            DispatchQueue.main.async {
                self.allContacts = contacts.sorted { c1, c2 in
                    let name1 = self.contactDisplayName(c1)
                    let name2 = self.contactDisplayName(c2)
                    return name1 < name2
                }
                self.isLoadingContacts = false
                print("After sorting: \(self.allContacts.count) contacts")
                
                // Debug: Print first few contacts
                for (index, contact) in self.allContacts.prefix(3).enumerated() {
                    print("Contact \(index): identifier=\(contact.identifier), name=\(self.contactDisplayName(contact))")
                }
                
                print("Existing contacts in app: \(self.existingContacts.count)")
                if !self.existingContacts.isEmpty {
                    for contact in self.existingContacts.prefix(3) {
                        print("Existing contact identifier: \(contact.contactIdentifier ?? "nil")")
                    }
                }
                
                let available = self.availableContacts
                print("Available contacts (not yet added): \(available.count)")
                for (index, contact) in available.prefix(3).enumerated() {
                    print("Available contact \(index): identifier=\(contact.identifier), name=\(self.contactDisplayName(contact))")
                }
            }
        } catch {
            print("Error enumerating contacts: \(error.localizedDescription)")
            print("Error details: \(error)")
            DispatchQueue.main.async {
                self.isLoadingContacts = false
            }
        }
    }
    
    // Helper to safely check if contact has photo (avoids CNPropertyNotFetchedException)
    private func safeHasPhoto(_ contact: CNContact) -> Bool {
        // Skip photo checking to avoid crashes - CNContact image properties throw exceptions
        // even when keys are available if the data wasn't properly fetched
        // Photo scoring is optional, so we'll skip it for safety
        return false
    }
    
    // Helper to get display name for a contact
    private func contactDisplayName(_ contact: CNContact) -> String {
        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty {
            return fullName
        }
        if !contact.nickname.isEmpty {
            return contact.nickname
        }
        if !contact.organizationName.isEmpty {
            return contact.organizationName
        }
        return "Unknown"
    }
    
    private func importContacts() {
        for selection in selectedContacts {
            let cnContact = selection.cnContact
            let name = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumber = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value as String?
            let birthday = cnContact.birthday?.date
            let imageData: Data? = cnContact.imageData ?? cnContact.thumbnailImageData
            
            // Default to Personal category
            let categoryIdentifier = ContactCategory.personal.rawValue
            let customCategoryId: UUID? = nil
            
            let contact = Contact(
                name: name.isEmpty ? "Unknown" : name,
                phoneNumber: phoneNumber,
                email: email,
                categoryIdentifier: categoryIdentifier,
                customCategoryId: customCategoryId,
                frequencyDays: selection.frequencyDays,
                photosPersonLocalIdentifier: nil,
                birthday: birthday,
                profileImageData: imageData,
                contactIdentifier: cnContact.identifier
            )
            
            modelContext.insert(contact)
        }
        
        dismiss()
    }
}

// Helper struct to track contact selection with frequency
struct ContactSelection: Identifiable {
    let id = UUID()
    let identifier: String
    let cnContact: CNContact
    var frequencyDays: Int
    var categoryIdentifier: String? = nil
    var customCategoryId: UUID? = nil
}

// Frequency button component
struct FrequencyButton: View {
    let frequency: Int
    let label: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Contact row for frequency assignment
struct ContactFrequencyRow: View {
    let cnContact: CNContact
    let selectedFrequency: Int
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var contactName: String {
        let fullName = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty {
            return fullName
        }
        if !cnContact.nickname.isEmpty {
            return cnContact.nickname
        }
        if !cnContact.organizationName.isEmpty {
            return cnContact.organizationName
        }
        return "Unknown"
    }
    
    var body: some View {
        HStack {
            Button {
                onToggle(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(contactName)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
}

// Search bar component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search contacts", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// Category picker sheet for contact selection
struct CategoryPickerSheetForSelection: View {
    let contactIdentifier: String
    let currentCategoryId: String?
    let currentCustomId: UUID?
    let customCategories: [CustomCategory]
    let categoryManager: CategoryManager
    let onCategoryChange: (String, String?, UUID?) -> Void
    @Binding var showingAddCategory: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Built-in categories
                ForEach(categoryManager.enabledCategories, id: \.self) { cat in
                    Button {
                        onCategoryChange(contactIdentifier, cat.rawValue, nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(cat.rawValue)
                                .foregroundColor(.blue)
                            Spacer()
                            if currentCategoryId == cat.rawValue && currentCustomId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Custom categories
                ForEach(customCategories, id: \.id) { customCat in
                    Button {
                        onCategoryChange(contactIdentifier, customCat.name, customCat.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(customCat.emoji)
                                .frame(width: 24, alignment: .leading)
                            Text(customCat.name)
                                .foregroundColor(.blue)
                            Spacer()
                            if currentCustomId == customCat.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Add new category button
                Button {
                    showingAddCategory = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Add New Category")
                            .foregroundColor(.blue)
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

// Add category sheet from picker
struct AddCategorySheetFromPicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customCategories: [CustomCategory]
    let contactIdentifier: String
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = ""
    @State private var showingEmojiPicker = false
    
    let onSave: (String?, UUID?) -> Void
    
    init(customCategories: [CustomCategory], contactIdentifier: String, onSave: @escaping (String?, UUID?) -> Void) {
        self.customCategories = customCategories
        self.contactIdentifier = contactIdentifier
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $newCategoryName)
                    
                    HStack {
                        if !newCategoryEmoji.isEmpty {
                            Text(newCategoryEmoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        } else {
                            Spacer()
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let maxOrder = customCategories.map { $0.order }.max() ?? -1
                        let newCategory = CustomCategory(
                            name: newCategoryName,
                            emoji: newCategoryEmoji,
                            icon: "tag.fill",
                            order: maxOrder + 1
                        )
                        modelContext.insert(newCategory)
                        // Pass the category name and ID to select it
                        onSave(newCategory.name, newCategory.id)
                        dismiss()
                    }
                    .disabled(newCategoryName.isEmpty || newCategoryEmoji.isEmpty)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerViewForAddContact(selectedEmoji: $newCategoryEmoji)
            }
        }
        .presentationDetents([.medium])
    }
}

// Emoji picker view for AddContactView
struct EmojiPickerViewForAddContact: View {
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
        .presentationDetents([.medium])
    }
}

// Extension to convert CNBirthday to Date
extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}
