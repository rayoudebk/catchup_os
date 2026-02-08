import SwiftUI
import SwiftData
@preconcurrency import Contacts
import OSLog

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingContacts: [Contact]

    let onImportCompleted: (() -> Void)?

    @State private var allContacts: [CNContact] = []
    @State private var selectedAssignments: [String: SocialCircle] = [:]
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var permissionDenied = false
    @State private var activeCircle: SocialCircle = .personal
    @State private var importError: String?
    @State private var sessionExcludedIdentifiers: Set<String> = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ContactNotes", category: "ContactImport")

    init(onImportCompleted: (() -> Void)? = nil) {
        self.onImportCompleted = onImportCompleted
    }

    private var selectedCount: Int {
        selectedAssignments.count
    }

    private var existingIdentifiers: Set<String> {
        Set(existingContacts.compactMap { $0.contactIdentifier })
    }

    private var excludedIdentifiers: Set<String> {
        existingIdentifiers.union(sessionExcludedIdentifiers)
    }

    private var availableContacts: [CNContact] {
        allContacts.filter { !excludedIdentifiers.contains($0.identifier) }
    }

    private var filteredContacts: [CNContact] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return availableContacts }

        return availableContacts.filter { contact in
            displayName(for: contact).localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var recommendedContacts: [CNContact] {
        let ranked = filteredContacts
            .map { ($0, richnessScore(for: $0)) }
            .filter { $0.1 >= 4 }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return displayName(for: $0.0).localizedCaseInsensitiveCompare(displayName(for: $1.0)) == .orderedAscending
            }

        return ranked.prefix(25).map { $0.0 }
    }

    private var nonRecommendedContacts: [CNContact] {
        let recommendedIds = Set(recommendedContacts.map { $0.identifier })
        return filteredContacts.filter { !recommendedIds.contains($0.identifier) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if permissionDenied {
                    permissionDeniedView
                } else {
                    VStack(spacing: 0) {
                        categoryPickerBar

                        List {
                            if availableContacts.isEmpty {
                                Section {
                                    Text("All address book contacts are already imported.")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                if !recommendedContacts.isEmpty {
                                    Section("Recommended") {
                                        ForEach(recommendedContacts, id: \.identifier) { contact in
                                            contactSelectionRow(contact)
                                        }
                                    }
                                }

                                Section(recommendedContacts.isEmpty ? "Address Book" : "All Contacts") {
                                    if nonRecommendedContacts.isEmpty {
                                        Text("No additional contacts match your search.")
                                            .foregroundColor(.secondary)
                                    } else {
                                        ForEach(nonRecommendedContacts, id: \.identifier) { contact in
                                            contactSelectionRow(contact)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Add Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isImporting ? "Importing..." : (selectedCount > 0 ? "Import \(selectedCount)" : "Import")) {
                        importSelectedContacts()
                    }
                    .disabled(selectedCount == 0 || isImporting)
                }
            }
            .task {
                await loadContacts()
            }
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var categoryPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SocialCircle.allCases, id: \.self) { circle in
                    Button {
                        activeCircle = circle
                    } label: {
                        Text(circle.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(activeCircle == circle ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                            .foregroundColor(activeCircle == circle ? .accentColor : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Contacts access is required to import people.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private func contactSelectionRow(_ contact: CNContact) -> some View {
        let contactName = displayName(for: contact)
        let assignedCircle = selectedAssignments[contact.identifier]

        Button {
            toggleSelection(for: contact.identifier)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: assignedCircle == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(assignedCircle == nil ? .secondary : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contactName)
                        .foregroundColor(.primary)

                    if let birthday = contact.birthday?.date {
                        Text("Birthday: \(birthday.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let assignedCircle {
                    Text(assignedCircle.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(for identifier: String) {
        if let assigned = selectedAssignments[identifier] {
            if assigned == activeCircle {
                selectedAssignments.removeValue(forKey: identifier)
            } else {
                selectedAssignments[identifier] = activeCircle
            }
        } else {
            selectedAssignments[identifier] = activeCircle
        }
    }

    private func loadContacts() async {
        if isLoading || !allContacts.isEmpty { return }

        isLoading = true
        defer { isLoading = false }

        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }

            if !granted {
                logger.warning("Contacts permission denied on first request")
                permissionDenied = true
                return
            }
        } else if status != .authorized {
            logger.warning("Contacts permission unavailable with status \(status.rawValue)")
            permissionDenied = true
            return
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        do {
            let loaded = try await fetchContacts(store: store, request: request)
            allContacts = loaded.sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
            }
            logger.info("Loaded \(loaded.count) address book contacts")
        } catch {
            logger.error("Failed loading contacts: \(error.localizedDescription, privacy: .public)")
            permissionDenied = true
        }
    }

    private func fetchContacts(store: CNContactStore, request: CNContactFetchRequest) async throws -> [CNContact] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var loaded: [CNContact] = []
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        loaded.append(contact)
                    }
                    continuation.resume(returning: loaded)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func importSelectedContacts() {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let selectedSnapshot = selectedAssignments
        guard !selectedSnapshot.isEmpty else {
            importError = "Select at least one contact to import."
            return
        }

        let excludedAtStart = excludedIdentifiers
        let byIdentifier = Dictionary(uniqueKeysWithValues: availableContacts.map { ($0.identifier, $0) })
        var importedIdentifiers: [String] = []
        var insertedContacts: [Contact] = []
        logger.info("Import started. selected=\(selectedSnapshot.count), available=\(availableContacts.count), excluded=\(excludedAtStart.count)")

        for (identifier, circle) in selectedSnapshot.sorted(by: { $0.key < $1.key }) {
            guard !excludedAtStart.contains(identifier) else { continue }
            guard let cnContact = byIdentifier[identifier] else { continue }

            let name = displayName(for: cnContact)
            let phone = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value as String?
            let birthday = cnContact.birthday?.date
            let imageData = cnContact.imageData ?? cnContact.thumbnailImageData

            let contact = Contact(
                name: name,
                phoneNumber: phone,
                email: email,
                birthday: birthday,
                birthdayNote: "",
                giftIdea: "",
                socialCircle: circle,
                isFavorite: false,
                profileImageData: imageData,
                contactIdentifier: cnContact.identifier
            )
            modelContext.insert(contact)
            insertedContacts.append(contact)
            importedIdentifiers.append(identifier)
        }

        do {
            try modelContext.save()
            logger.info("Import save succeeded. inserted=\(insertedContacts.count)")
        } catch {
            for contact in insertedContacts {
                modelContext.delete(contact)
            }
            logger.error("Import save failed. inserted=\(insertedContacts.count), error=\(error.localizedDescription, privacy: .public)")
            importError = "Could not import contacts: \(error.localizedDescription)"
            return
        }

        for contact in insertedContacts {
            try? BirthdayReminderManager.shared.scheduleAnnual(for: contact)
        }

        sessionExcludedIdentifiers.formUnion(importedIdentifiers)
        for identifier in importedIdentifiers {
            selectedAssignments.removeValue(forKey: identifier)
        }

        guard !importedIdentifiers.isEmpty else {
            logger.warning("Import finished with zero inserted contacts")
            importError = "No new contacts were imported."
            return
        }

        let importedSet = Set(importedIdentifiers)
        allContacts.removeAll { importedSet.contains($0.identifier) }
        logger.info("Import completed. imported=\(importedSet.count)")

        onImportCompleted?()
        dismiss()
    }

    private func displayName(for contact: CNContact) -> String {
        let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { return full }
        if !contact.nickname.isEmpty { return contact.nickname }
        if !contact.organizationName.isEmpty { return contact.organizationName }
        return "Unknown"
    }

    private func richnessScore(for contact: CNContact) -> Int {
        var score = 0

        let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { score += 2 }
        if !contact.nickname.isEmpty { score += 1 }
        if !contact.organizationName.isEmpty { score += 1 }

        if !contact.phoneNumbers.isEmpty { score += 2 }
        if contact.phoneNumbers.count > 1 { score += 1 }

        if !contact.emailAddresses.isEmpty { score += 2 }
        if contact.emailAddresses.count > 1 { score += 1 }

        if contact.birthday != nil { score += 1 }
        if contact.imageData != nil || contact.thumbnailImageData != nil { score += 1 }

        return score
    }
}

private extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}
