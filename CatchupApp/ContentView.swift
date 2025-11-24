import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query private var checkIns: [CheckIn]
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @ObservedObject private var categoryManager = CategoryManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingAddContact = false
    @State private var searchText = ""
    @State private var selectedCategoryIdentifier: String? // For built-in categories
    @State private var selectedCustomCategoryId: UUID? // For custom categories
    @State private var showingOverdueOnly = false
    @State private var showingRecentCatchupsOnly = false
    @State private var sortOption: SortOption = .name
    @State private var showingOnboarding = false
    @State private var showingAddCategoryBanner = true
    @State private var showingAddCategorySheet = false
    @State private var isAddingFromOnboarding = false
    @State private var showingRecordCheckInSheet = false
    
    var filteredContacts: [Contact] {
        var filtered = contacts
        
        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by overdue status
        if showingOverdueOnly {
            filtered = filtered.filter { $0.isOverdue }
        }
        
        // Filter by recent catchups (last 7 days)
        if showingRecentCatchupsOnly {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = filtered.filter { contact in
                if let lastCheckIn = contact.lastCheckInDate {
                    return lastCheckIn >= sevenDaysAgo
                }
                return false
            }
        }
        
        // Filter by category
        if let categoryId = selectedCategoryIdentifier {
            filtered = filtered.filter { $0.categoryIdentifier == categoryId && $0.customCategoryId == nil }
        } else if let customId = selectedCustomCategoryId {
            filtered = filtered.filter { $0.customCategoryId == customId }
        }
        
        // Sort: Favorites first, then by selected sort option
        filtered.sort { (c1, c2) in
            // Favorites always come first
            if c1.isFavorite != c2.isFavorite {
                return c1.isFavorite
            }
            
            // Within same favorite status, sort by selected option
        switch sortOption {
        case .name:
                return c1.name < c2.name
        case .overdue:
                if c1.isOverdue != c2.isOverdue {
                    return c1.isOverdue
                }
                return c1.daysUntilNextCheckIn < c2.daysUntilNextCheckIn
        case .recentCheckIn:
                guard let d1 = c1.lastCheckInDate, let d2 = c2.lastCheckInDate else {
                    return c1.lastCheckInDate != nil
                }
                return d1 > d2
            }
        }
        
        return filtered
    }
    
    var overdueCount: Int {
        contacts.filter { $0.isOverdue }.count
    }
    
    var recentCatchupsCount: Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return contacts.filter { contact in
            if let lastCheckIn = contact.lastCheckInDate {
                return lastCheckIn >= sevenDaysAgo
            }
            return false
        }.count
    }
    
    // Unified category list sorted by order (allows interleaving)
    struct CategoryItem: Identifiable {
        let id: String
        let builtInCategory: ContactCategory?
        let customCategory: CustomCategory?
        let order: Int
    }
    
    var allCategoriesSorted: [CategoryItem] {
        var items: [CategoryItem] = []
        
        // Add built-in categories
        for category in categoryManager.enabledCategories {
            items.append(CategoryItem(
                id: category.rawValue,
                builtInCategory: category,
                customCategory: nil,
                order: categoryManager.getOrder(for: category)
            ))
        }
        
        // Add custom categories
        for customCat in customCategories {
            items.append(CategoryItem(
                id: customCat.id.uuidString,
                builtInCategory: nil,
                customCategory: customCat,
                order: customCat.order
            ))
        }
        
        // Sort by order - allows true interleaving!
        return items.sorted { $0.order < $1.order }
    }
    
    var greeting: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date()) // 1 = Sunday, 2 = Monday, etc.
        
        // Check for special days
        if weekday == 2 { // Monday
            return "Happy Monday!"
        } else if weekday == 6 { // Friday
            return "Happy Friday!"
        }
        
        // Time-based greetings
        if hour < 12 {
            return "Good morning!"
        } else if hour < 17 {
            return "Good afternoon!"
        } else {
            return "Good evening!"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Header - Always show
                    StatsHeaderView(
                    overdueCount: overdueCount,
                    recentCatchupsCount: recentCatchupsCount,
                    showingOverdueOnly: $showingOverdueOnly,
                    showingRecentCatchupsOnly: $showingRecentCatchupsOnly,
                    onOverdueToggle: {
                        if showingOverdueOnly {
                            selectedCategoryIdentifier = nil
                            selectedCustomCategoryId = nil
                            showingRecentCatchupsOnly = false
                        }
                    },
                    onRecentCatchupsToggle: {
                        if showingRecentCatchupsOnly {
                            selectedCategoryIdentifier = nil
                            selectedCustomCategoryId = nil
                            showingOverdueOnly = false
                        }
                    },
                    onRecordCheckIn: {
                        showingRecordCheckInSheet = true
                    }
                    )
                    .padding()
                
                // Category Filter - Unified order
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategoryIdentifier == nil && selectedCustomCategoryId == nil,
                            count: contacts.count
                        ) {
                            selectedCategoryIdentifier = nil
                            selectedCustomCategoryId = nil
                            showingOverdueOnly = false
                            showingRecentCatchupsOnly = false
                        }
                        
                        // Combine built-in and custom categories, sorted by order
                        ForEach(allCategoriesSorted, id: \.id) { categoryItem in
                            if let builtIn = categoryItem.builtInCategory {
                                CategoryFilterButton(
                                    title: builtIn.rawValue,
                                    icon: builtIn.icon,
                                    isSelected: selectedCategoryIdentifier == builtIn.rawValue,
                                    count: contacts.filter { $0.categoryIdentifier == builtIn.rawValue && $0.customCategoryId == nil }.count
                                ) {
                                    selectedCategoryIdentifier = builtIn.rawValue
                                    selectedCustomCategoryId = nil
                                    showingOverdueOnly = false
                                    showingRecentCatchupsOnly = false
                                }
                            } else if let customCat = categoryItem.customCategory {
                            CategoryFilterButton(
                                    title: customCat.name,
                                    emoji: customCat.emoji,
                                    isSelected: selectedCustomCategoryId == customCat.id,
                                    count: contacts.filter { $0.customCategoryId == customCat.id }.count
                            ) {
                                    selectedCustomCategoryId = customCat.id
                                    selectedCategoryIdentifier = nil
                                    showingOverdueOnly = false
                                    showingRecentCatchupsOnly = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // Category Banner - Show below category pills
                if showingAddCategoryBanner {
                    CategoryBannerView(
                        onDismiss: {
                            showingAddCategoryBanner = false
                        },
                        onAddCategory: {
                            showingAddCategorySheet = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Contacts List
                if filteredContacts.isEmpty {
                    EmptyStateView(hasContacts: !contacts.isEmpty)
                } else {
                    List {
                        ForEach(filteredContacts) { contact in
                            NavigationLink(destination: ContactDetailView(contact: contact)) {
                                ContactRowView(contact: contact)
                            }
                        }
                        .onDelete(perform: deleteContacts)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingFromOnboarding = false
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView(isFromOnboarding: isAddingFromOnboarding)
            }
            .sheet(isPresented: $showingAddCategorySheet) {
                AddCategoryBannerSheetView()
            }
            .sheet(isPresented: $showingRecordCheckInSheet) {
                RecordCheckInSheetView(contacts: contacts)
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showingOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView(isFromOnboarding: true) {
                    hasSeenOnboarding = true
                    showingOnboarding = false
                    // After onboarding, prompt to add contacts
                    isAddingFromOnboarding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingAddContact = true
                    }
                }
            }
        }
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            let contact = filteredContacts[index]
            modelContext.delete(contact)
        }
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case overdue = "Due Soon"
    case recentCheckIn = "Recent Check-ins"
    
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .overdue: return "exclamationmark.circle"
        case .recentCheckIn: return "clock"
        }
    }
}

struct OnboardingView: View {
    let isFromOnboarding: Bool
    let onContinue: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Contact + Notes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Stay connected with the people who matter")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            introCard(
                                title: "Why Contact + Notes?",
                                description: "Busy schedule? Losing touch with friends and connections over time? Contact + Notes gives you a simple reminder system so important relationships never slip through the cracks."
                            )
                            
                            OnboardingSection(
                                icon: "person.badge.plus",
                                title: "Add your contacts",
                                message: "Start with just a few people—import them from your phone and grow your list whenever you're ready."
                            )
                            
                            OnboardingSection(
                                icon: "slider.horizontal.3",
                                title: "Edit the details",
                                message: "Choose the right category, set how often you want to catch up, and customize reminders that fit your rhythm."
                            )
                            
                            OnboardingSection(
                                icon: "doc.text.magnifyingglass",
                                title: "Record your catchups",
                                message: "Better than scattered notes or voice memos—log what stood out and keep it private on your phone."
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Let's start by adding 5 contacts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: onContinue) {
                            Text("Get started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    private func introCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

private struct OnboardingSection: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

// Category Banner View - shown below category pills on homepage
struct CategoryBannerView: View {
    let onDismiss: () -> Void
    let onAddCategory: () -> Void
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            Button(action: onAddCategory) {
                HStack {
                    Text("Add categories to organize contacts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = -UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// Add Category Banner Sheet View - bucket-based UI similar to add contacts flow
struct AddCategoryBannerSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @ObservedObject private var categoryManager = CategoryManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategoryId: String? // For built-in categories
    @State private var selectedCustomCategoryId: UUID? // For custom categories
    @State private var contactCategoryMap: [UUID: (categoryId: String?, customId: UUID?)] = [:]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = ""
    
    // All categories sorted by order (excluding Personal as it's the catch-all)
    var allCategoriesSorted: [CategoryItem] {
        var items: [CategoryItem] = []
        
        // Add built-in categories (excluding Personal)
        for category in categoryManager.enabledCategories where category != .personal {
            items.append(CategoryItem(
                id: category.rawValue,
                builtInCategory: category,
                customCategory: nil,
                order: categoryManager.getOrder(for: category)
            ))
        }
        
        // Add custom categories
        for customCat in customCategories {
            items.append(CategoryItem(
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
            .navigationTitle("Add Category")
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
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheetFromBanner(
                    newCategoryName: $newCategoryName,
                    newCategoryEmoji: $newCategoryEmoji,
                    onSave: {
                        addNewCategory()
                    },
                    onDismiss: {
                        newCategoryName = ""
                        newCategoryEmoji = ""
                    }
                )
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
                    newCategoryButton
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    @ViewBuilder
    private func categoryButton(for categoryItem: CategoryItem) -> some View {
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
    
    private var newCategoryButton: some View {
        Button {
            showingAddCategory = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("New")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("category")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.8))
            }
            .frame(width: 100, height: 80)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
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
    
    private func addNewCategory() {
        guard !newCategoryName.isEmpty && !newCategoryEmoji.isEmpty else { return }
        
        // Find the maximum order value among all categories
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
        
        do {
            try modelContext.save()
            categoryManager.refreshTrigger = UUID()
            newCategoryName = ""
            newCategoryEmoji = ""
            showingAddCategory = false
        } catch {
            print("Error saving category: \(error)")
        }
    }
}

// Add category sheet from banner
struct AddCategorySheetFromBanner: View {
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
                        // Left side: Display selected emoji
                        if !newCategoryEmoji.isEmpty {
                            Text(newCategoryEmoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        } else {
                            Spacer()
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        // Right side: Blue emoji button
                        Button {
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
        .interactiveDismissDisabled(true)
    }
}

// Category bucket button component
struct CategoryBucketButton: View {
    let title: String
    var icon: String? = nil
    var emoji: String? = nil
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Always show emoji if available, otherwise show icon
                if let emoji = emoji {
                    Text(emoji)
                        .font(.title2)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                }
                
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

// Contact category row for the list
struct ContactCategoryRow: View {
    let contact: Contact
    let selectedCategoryId: String?
    let selectedCustomCategoryId: UUID?
    let isSelected: Bool // Pass the selection state directly
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

struct CategoryItem: Identifiable {
    let id: String
    let builtInCategory: ContactCategory?
    let customCategory: CustomCategory?
    let order: Int
}


