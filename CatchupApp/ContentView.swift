import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name, order: .forward) private var contacts: [Contact]
    @Query private var notes: [ContactNote]

    @State private var searchText = ""
    @State private var selectedCircle: SocialCircle?
    @State private var showingAddContact = false
    @State private var didRunStartup = false
    @State private var startupError: String?

    private let categoryManager = CategoryManager.shared
    private let importGoal = 5
    private let noteGoal = 3
    private let giftIdeaGoal = 1

    private var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let searchFiltered = query.isEmpty ? contacts : contacts.filter { contact in
            if contact.name.localizedCaseInsensitiveContains(query) {
                return true
            }

            if let latest = contact.latestNote,
               latest.body.localizedCaseInsensitiveContains(query) {
                return true
            }

            return (contact.notes ?? []).contains { note in
                note.body.localizedCaseInsensitiveContains(query)
            }
        }

        let circleFiltered = searchFiltered.filter { contact in
            guard let selectedCircle else { return true }
            return contact.socialCircle == selectedCircle
        }

        return circleFiltered.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                onboardingBanner
                socialCircleFilter

                Group {
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
            }
            .navigationTitle("Contacts+Notes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search contacts or notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView {
                    selectedCircle = nil
                    searchText = ""
                }
            }
            .task {
                guard !didRunStartup else { return }
                didRunStartup = true

                do {
                    try LegacyDataMigrator.migrateIfNeeded(context: modelContext)
                    BirthdayReminderManager.shared.refreshAll(contacts: contacts)
                } catch {
                    startupError = error.localizedDescription
                }
            }
            .alert(
                "Startup issue",
                isPresented: Binding(
                    get: { startupError != nil },
                    set: { newValue in
                        if !newValue { startupError = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) { startupError = nil }
            } message: {
                Text(startupError ?? "")
            }
        }
    }

    private var onboardingBanner: some View {
        let imported = min(contacts.count, importGoal)
        let recordedNotes = min(notes.count, noteGoal)
        let giftIdeas = min(
            contacts.filter { !$0.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
            giftIdeaGoal
        )
        let completedUnits = imported + recordedNotes + giftIdeas
        let totalUnits = importGoal + noteGoal + giftIdeaGoal
        let progress = Double(completedUnits) / Double(totalUnits)

        return VStack(alignment: .leading, spacing: 8) {
            Text(completedUnits >= totalUnits ? "Onboarding Complete" : "Onboarding Progress")
                .font(.subheadline)
                .fontWeight(.semibold)

            ProgressView(value: progress)
                .tint(.accentColor)

            Text("\(completedUnits)/\(totalUnits) completed")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                onboardingStepLabel(title: "Import \(importGoal)", value: imported, goal: importGoal)
                onboardingStepLabel(title: "Record \(noteGoal) notes", value: recordedNotes, goal: noteGoal)
                onboardingStepLabel(title: "Add 1 gift idea", value: giftIdeas, goal: giftIdeaGoal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    private func onboardingStepLabel(title: String, value: Int, goal: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: value >= goal ? "checkmark.circle.fill" : "circle")
                .foregroundColor(value >= goal ? .green : .secondary)
            Text("\(title): \(value)/\(goal)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var socialCircleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", selected: selectedCircle == nil) {
                    selectedCircle = nil
                }

                ForEach(categoryManager.all) { definition in
                    filterChip(
                        title: definition.title,
                        icon: definition.icon,
                        selected: selectedCircle == definition.circle,
                        color: definition.color
                    ) {
                        selectedCircle = definition.circle
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func filterChip(
        title: String,
        icon: String? = nil,
        selected: Bool,
        color: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? color.opacity(0.18) : Color(.secondarySystemBackground))
            .foregroundColor(selected ? color : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredContacts[index])
        }
        try? modelContext.save()
    }
}
