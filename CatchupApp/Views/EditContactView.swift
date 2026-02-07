import SwiftUI
import SwiftData

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var contact: Contact

    @State private var hasBirthday = false
    @State private var birthdayDraft = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $contact.name)

                    Picker("Social Circle", selection: Binding(
                        get: { contact.socialCircle },
                        set: { contact.socialCircle = $0 }
                    )) {
                        ForEach(SocialCircle.allCases, id: \.self) { circle in
                            Text(circle.title).tag(circle)
                        }
                    }

                    TextField(
                        "Phone Number",
                        text: Binding(
                            get: { contact.phoneNumber ?? "" },
                            set: { contact.phoneNumber = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .keyboardType(.phonePad)

                    TextField(
                        "Email",
                        text: Binding(
                            get: { contact.email ?? "" },
                            set: { contact.email = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                }

                Section("Birthday") {
                    Toggle("Has birthday", isOn: $hasBirthday)

                    if hasBirthday {
                        DatePicker(
                            "Birthday",
                            selection: $birthdayDraft,
                            displayedComponents: [.date]
                        )

                        TextField("Birthday note", text: $contact.birthdayNote, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                Section("Gift Idea") {
                    TextField("What would they appreciate?", text: $contact.giftIdea, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Options") {
                    Toggle(isOn: $contact.isFavorite) {
                        Label("Favorite", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                    }
                    .disabled(contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                hasBirthday = contact.birthday != nil
                birthdayDraft = contact.birthday ?? Date()
            }
        }
    }

    private func save() {
        contact.birthday = hasBirthday ? birthdayDraft : nil
        contact.giftIdea = contact.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasBirthday {
            try? BirthdayReminderManager.shared.scheduleAnnual(for: contact)
        } else {
            BirthdayReminderManager.shared.cancel(for: contact)
            contact.birthdayNote = ""
        }

        try? modelContext.save()
        dismiss()
    }
}
