import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name, order: .forward) private var contacts: [Contact]
    @Query private var notes: [ContactNote]

    @State private var searchText = ""
    @State private var selectedCircle: SocialCircle?
    @State private var showingAddContact = false
    @State private var showingQuickNoteComposer = false
    @State private var showingQuickGiftIdeaEditor = false
    @State private var didRunStartup = false
    @State private var startupError: String?

    private let categoryManager = CategoryManager.shared

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

    private var completedContactStep: Bool {
        contacts.count >= 1
    }

    private var completedNoteStep: Bool {
        notes.count >= 1
    }

    private var completedGiftStep: Bool {
        contacts.contains { !$0.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var activeOnboardingStep: OnboardingStep? {
        if !completedContactStep { return .addContact }
        if !completedNoteStep { return .recordNote }
        if !completedGiftStep { return .addGiftIdea }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                socialCircleFilter

                if let step = activeOnboardingStep {
                    onboardingCard(for: step)
                }

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
            .navigationBarTitleDisplayMode(.inline)
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
            .safeAreaInset(edge: .bottom) {
                bottomSearchBar
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView {
                    selectedCircle = nil
                    searchText = ""
                }
            }
            .sheet(isPresented: $showingQuickNoteComposer) {
                QuickNoteComposerView(preselectedContactID: contacts.first?.id)
            }
            .sheet(isPresented: $showingQuickGiftIdeaEditor) {
                QuickGiftIdeaComposerView(preselectedContactID: contacts.first?.id)
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

    private func onboardingCard(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Onboarding")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(step.title)
                .font(.headline)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("Step \(step.stepNumber) of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(step.actionTitle) {
                    handleOnboardingAction(step)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    private func handleOnboardingAction(_ step: OnboardingStep) {
        switch step {
        case .addContact:
            showingAddContact = true
        case .recordNote:
            showingQuickNoteComposer = true
        case .addGiftIdea:
            showingQuickGiftIdeaEditor = true
        }
    }

    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search contacts or notes", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())

            Button {
                showingQuickNoteComposer = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(contacts.isEmpty)
            .opacity(contacts.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

private enum OnboardingStep {
    case addContact
    case recordNote
    case addGiftIdea

    var stepNumber: Int {
        switch self {
        case .addContact:
            return 1
        case .recordNote:
            return 2
        case .addGiftIdea:
            return 3
        }
    }

    var title: String {
        switch self {
        case .addContact:
            return "Add your first contact"
        case .recordNote:
            return "Record your first note"
        case .addGiftIdea:
            return "Add a gift idea"
        }
    }

    var subtitle: String {
        switch self {
        case .addContact:
            return "Import one contact from your address book to get started."
        case .recordNote:
            return "Create one note for any contact to start building context."
        case .addGiftIdea:
            return "Add a gift idea on one profile to complete onboarding."
        }
    }

    var actionTitle: String {
        switch self {
        case .addContact:
            return "Add Contact"
        case .recordNote:
            return "New Note"
        case .addGiftIdea:
            return "Add Gift Idea"
        }
    }
}

private struct QuickNoteComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name, order: .forward) private var contacts: [Contact]

    @State private var selectedContactID: UUID?
    @State private var noteText = ""
    @State private var composerError: String?

    init(preselectedContactID: UUID? = nil) {
        _selectedContactID = State(initialValue: preselectedContactID)
    }

    var body: some View {
        NavigationStack {
            Form {
                if contacts.isEmpty {
                    Text("Add at least one contact before creating notes.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Contact", selection: $selectedContactID) {
                        Text("Select Contact").tag(nil as UUID?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(Optional(contact.id))
                        }
                    }
                }

                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(
                        contacts.isEmpty ||
                        selectedContact == nil ||
                        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .alert(
                "Note Error",
                isPresented: Binding(
                    get: { composerError != nil },
                    set: { newValue in
                        if !newValue { composerError = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) { composerError = nil }
            } message: {
                Text(composerError ?? "")
            }
            .onAppear {
                if selectedContactID == nil {
                    selectedContactID = contacts.first?.id
                }
            }
        }
    }

    private var selectedContact: Contact? {
        guard let selectedContactID else { return nil }
        return contacts.first(where: { $0.id == selectedContactID })
    }

    private func save() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let selectedContact else {
            composerError = "Please select a contact."
            return
        }

        let note = ContactNote(
            createdAt: Date(),
            updatedAt: Date(),
            body: trimmed,
            source: .typed,
            transcriptLanguage: Locale.current.identifier,
            audioDurationSec: nil,
            contact: selectedContact
        )

        modelContext.insert(note)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            composerError = "Could not save note: \(error.localizedDescription)"
        }
    }
}

private struct QuickGiftIdeaComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name, order: .forward) private var contacts: [Contact]

    @State private var selectedContactID: UUID?
    @State private var giftIdeaText = ""
    @State private var composerError: String?

    init(preselectedContactID: UUID? = nil) {
        _selectedContactID = State(initialValue: preselectedContactID)
    }

    var body: some View {
        NavigationStack {
            Form {
                if contacts.isEmpty {
                    Text("Add at least one contact before adding gift ideas.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Contact", selection: $selectedContactID) {
                        Text("Select Contact").tag(nil as UUID?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(Optional(contact.id))
                        }
                    }
                }

                Section("Gift Idea") {
                    TextEditor(text: $giftIdeaText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Gift Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(
                        contacts.isEmpty ||
                        selectedContact == nil ||
                        giftIdeaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .alert(
                "Gift Idea Error",
                isPresented: Binding(
                    get: { composerError != nil },
                    set: { newValue in
                        if !newValue { composerError = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) { composerError = nil }
            } message: {
                Text(composerError ?? "")
            }
            .onAppear {
                if selectedContactID == nil {
                    selectedContactID = contacts.first?.id
                }
                updateDraftFromSelectedContact()
            }
            .onChange(of: selectedContactID) { _, _ in
                updateDraftFromSelectedContact()
            }
        }
    }

    private var selectedContact: Contact? {
        guard let selectedContactID else { return nil }
        return contacts.first(where: { $0.id == selectedContactID })
    }

    private func updateDraftFromSelectedContact() {
        giftIdeaText = selectedContact?.giftIdea ?? ""
    }

    private func save() {
        let trimmed = giftIdeaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let selectedContact else {
            composerError = "Please select a contact."
            return
        }

        selectedContact.giftIdea = trimmed

        do {
            try modelContext.save()
            dismiss()
        } catch {
            composerError = "Could not save gift idea: \(error.localizedDescription)"
        }
    }
}
