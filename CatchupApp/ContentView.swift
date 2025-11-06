import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var showingAddContact = false
    @State private var searchText = ""
    @State private var selectedCategory: ContactCategory?
    @State private var sortOption: SortOption = .name
    
    var filteredContacts: [Contact] {
        var filtered = contacts
        
        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Sort
        switch sortOption {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .overdue:
            filtered.sort { (c1, c2) in
                if c1.isOverdue != c2.isOverdue {
                    return c1.isOverdue
                }
                return c1.daysUntilNextCheckIn < c2.daysUntilNextCheckIn
            }
        case .recentCheckIn:
            filtered.sort { (c1, c2) in
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Header
                if !contacts.isEmpty {
                    StatsHeaderView(
                        totalContacts: contacts.count,
                        overdueCount: overdueCount
                    )
                    .padding()
                }
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            count: contacts.count
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(ContactCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                count: contacts.filter { $0.category == category }.count
                            ) {
                                selectedCategory = category
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
            .navigationTitle("Catchup")
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

