import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query private var checkIns: [CheckIn]
    @ObservedObject private var categoryManager = CategoryManager.shared
    @State private var showingAddContact = false
    @State private var searchText = ""
    @State private var selectedCategory: ContactCategory?
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
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
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
                            selectedCategory = nil
                            showingRecentCatchupsOnly = false
                        }
                    },
                    onRecentCatchupsToggle: {
                        if showingRecentCatchupsOnly {
                            selectedCategory = nil
                            showingOverdueOnly = false
                        }
                    }
                )
                .padding()
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            count: contacts.count
                        ) {
                            selectedCategory = nil
                            showingOverdueOnly = false
                            showingRecentCatchupsOnly = false
                        }
                        
                        ForEach(categoryManager.enabledCategories, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                count: contacts.filter { $0.category == category }.count
                            ) {
                                selectedCategory = category
                                showingOverdueOnly = false
                                showingRecentCatchupsOnly = false
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

