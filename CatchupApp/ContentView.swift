import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query private var checkIns: [CheckIn]
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @ObservedObject private var categoryManager = CategoryManager.shared
    @State private var showingAddContact = false
    @State private var searchText = ""
    @State private var selectedCategoryIdentifier: String? // For built-in categories
    @State private var selectedCustomCategoryId: UUID? // For custom categories
    @State private var showingOverdueOnly = false
    @State private var showingRecentCatchupsOnly = false
    @State private var sortOption: SortOption = .name
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView()
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

