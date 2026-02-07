import SwiftUI
import SwiftData
import Contacts

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingContacts: [Contact]

    @State private var allContacts: [CNContact] = []
    @State private var selectedIdentifiers: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var permissionDenied = false

    @State private var selectedSocialCircle: SocialCircle = .personal
    @State private var giftIdeaDraft = ""

    private var existingIdentifiers: Set<String> {
        Set(existingContacts.compactMap { $0.contactIdentifier })
    }

    private var availableContacts: [CNContact] {
        allContacts.filter { !existingIdentifiers.contains($0.identifier) }
    }

    private var filteredContacts: [CNContact] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return availableContacts }

        return availableContacts.filter { contact in
            displayName(for: contact).localizedCaseInsensitiveContains(trimmed)
        }
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
                    List {
                        Section("Defaults") {
                            Picker("Social Circle", selection: $selectedSocialCircle) {
                                ForEach(SocialCircle.allCases, id: \.self) { circle in
                                    Text(circle.title).tag(circle)
                                }
                            }

                            TextField("Gift idea (optional)", text: $giftIdeaDraft, axis: .vertical)
                                .lineLimit(2...4)
                        }

                        Section("Address Book") {
                            if filteredContacts.isEmpty {
                                Text(availableContacts.isEmpty ? "No contacts available to import." : "No matching contacts.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(filteredContacts, id: \.identifier) { contact in
                                    Button {
                                        toggleSelection(for: contact.identifier)
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedIdentifiers.contains(contact.identifier) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedIdentifiers.contains(contact.identifier) ? .blue : .secondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(displayName(for: contact))
                                                    .foregroundColor(.primary)
                                                if let birthday = contact.birthday?.date {
                                                    Text("Birthday: \(birthday.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importSelectedContacts()
                    }
                    .disabled(selectedIdentifiers.isEmpty)
                }
            }
            .task {
                await loadContacts()
            }
        }
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

    private func toggleSelection(for identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
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
                permissionDenied = true
                return
            }
        } else if status != .authorized {
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

        var loaded: [CNContact] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                loaded.append(contact)
            }
            allContacts = loaded.sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
            }
        } catch {
            permissionDenied = true
        }
    }

    private func importSelectedContacts() {
        let chosen = availableContacts.filter { selectedIdentifiers.contains($0.identifier) }

        for cnContact in chosen {
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
                giftIdea: giftIdeaDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                socialCircle: selectedSocialCircle,
                isFavorite: false,
                profileImageData: imageData,
                contactIdentifier: cnContact.identifier
            )
            modelContext.insert(contact)
            try? BirthdayReminderManager.shared.scheduleAnnual(for: contact)
        }

        try? modelContext.save()
        dismiss()
    }

    private func displayName(for contact: CNContact) -> String {
        let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { return full }
        if !contact.nickname.isEmpty { return contact.nickname }
        if !contact.organizationName.isEmpty { return contact.organizationName }
        return "Unknown"
    }
}

private extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}
