import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [Contact]
    @Query private var notes: [ContactNote]
    @Query private var legacyCheckIns: [CheckIn]

    @StateObject private var modelManager = WhisperModelManager.shared

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingShareSheet = false
    @State private var exportPayload = ""
    @State private var exportSubject = "Contact+Notes Export"
    @State private var showingClearAlert = false
    @State private var modelActionError: String?

    var body: some View {
        List {
            Section("Privacy") {
                Text("All records are stored on this iPhone only.")
                Text("No cloud backend and no iCloud sync in this version.")
                    .foregroundColor(.secondary)
            }

            Section("Birthday Reminders") {
                HStack {
                    Text("Permission")
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundColor(.secondary)
                }

                Button("Enable Birthday Reminders") {
                    BirthdayReminderManager.shared.requestAuthorization()
                    refreshNotificationStatus()
                }

                Button("Open Notification Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section("On-Device Transcription") {
                modelRow(for: .largeV3, recommended: true)
                modelRow(for: .largeV3Turbo, recommended: false)

                if !modelManager.lastFallbackReason.isEmpty {
                    Text("Last fallback: \(modelManager.lastFallbackReason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Data") {
                HStack {
                    Text("Contacts")
                    Spacer()
                    Text("\(contacts.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Notes")
                    Spacer()
                    Text("\(notes.count)")
                        .foregroundColor(.secondary)
                }

                Button("Export Data") {
                    exportData()
                }

                Button("Export to Apple Notes") {
                    exportToAppleNotes()
                }

                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Text("Clear All Data")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportPayload], subject: exportSubject)
        }
        .alert("Clear All Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This permanently deletes all contacts and notes on this device.")
        }
        .alert("Model Action Error", isPresented: Binding(
            get: { modelActionError != nil },
            set: { if !$0 { modelActionError = nil } }
        )) {
            Button("OK", role: .cancel) { modelActionError = nil }
        } message: {
            Text(modelActionError ?? "")
        }
        .onAppear {
            refreshNotificationStatus()
        }
    }

    @ViewBuilder
    private func modelRow(for model: WhisperModelVariant, recommended: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommended ? "\(model.rawValue) (Recommended)" : model.rawValue)
                Text(modelManager.fileSizeDescription(for: model))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if modelManager.isModelAvailable(model) {
                Button("Remove", role: .destructive) {
                    do {
                        try modelManager.removeModel(model)
                    } catch {
                        modelActionError = error.localizedDescription
                    }
                }
                .disabled(modelManager.isDownloading)
            } else {
                Button(modelManager.isDownloading ? "Downloading..." : "Download") {
                    Task {
                        modelManager.preferredModel = model
                        do {
                            try await modelManager.downloadModel(model)
                        } catch {
                            await MainActor.run {
                                modelActionError = error.localizedDescription
                            }
                        }
                    }
                }
                .disabled(modelManager.isDownloading)
            }
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func exportData() {
        let contactPayload = contacts.map { contact in
            [
                "id": contact.id.uuidString,
                "name": contact.name,
                "phoneNumber": contact.phoneNumber ?? "",
                "email": contact.email ?? "",
                "birthday": contact.birthday?.ISO8601Format() ?? "",
                "birthdayNote": contact.birthdayNote,
                "giftIdea": contact.giftIdea,
                "socialCircle": contact.socialCircle.rawValue,
                "isFavorite": contact.isFavorite,
                "createdAt": contact.createdAt.ISO8601Format()
            ] as [String: Any]
        }

        let notePayload = notes.map { note in
            [
                "id": note.id.uuidString,
                "createdAt": note.createdAt.ISO8601Format(),
                "updatedAt": note.updatedAt.ISO8601Format(),
                "body": note.body,
                "source": note.source.rawValue,
                "transcriptLanguage": note.transcriptLanguage ?? "",
                "audioDurationSec": note.audioDurationSec ?? 0,
                "contactId": note.contact?.id.uuidString ?? ""
            ] as [String: Any]
        }

        let payload: [String: Any] = [
            "exportDate": Date().ISO8601Format(),
            "storage": "on-device-only",
            "contacts": contactPayload,
            "notes": notePayload
        ]

        if
            let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
            let json = String(data: data, encoding: .utf8)
        {
            exportPayload = json
            exportSubject = "Contact+Notes JSON Export"
            showingShareSheet = true
        }
    }

    private func exportToAppleNotes() {
        let noteTimestampFormatter = DateFormatter()
        noteTimestampFormatter.dateStyle = .medium
        noteTimestampFormatter.timeStyle = .short

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateStyle = .long
        dateOnlyFormatter.timeStyle = .none

        var lines: [String] = []
        lines.append("Contact+Notes")
        lines.append("Exported on \(noteTimestampFormatter.string(from: Date()))")
        lines.append("Contacts: \(contacts.count) | Notes: \(notes.count)")
        lines.append("Tip: In the share sheet, choose Notes to save this as a native Apple Note.")
        lines.append("")

        let sortedContacts = contacts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        for contact in sortedContacts {
            lines.append(contact.isFavorite ? "★ \(contact.name)" : contact.name)
            lines.append(String(repeating: "-", count: max(12, contact.name.count)))
            lines.append("Social circle: \(contact.socialCircle.title)")

            if let phone = contact.phoneNumber, !phone.isEmpty {
                lines.append("Phone: \(phone)")
            }

            if let email = contact.email, !email.isEmpty {
                lines.append("Email: \(email)")
            }

            if let birthday = contact.birthday {
                lines.append("Birthday: \(dateOnlyFormatter.string(from: birthday))")
            }

            let birthdayNote = contact.birthdayNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !birthdayNote.isEmpty {
                lines.append("Birthday note: \(birthdayNote)")
            }

            let giftIdea = contact.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines)
            if !giftIdea.isEmpty {
                lines.append("Gift idea: \(giftIdea)")
            }

            lines.append("Notes:")
            if contact.sortedNotes.isEmpty {
                lines.append("- No notes yet")
            } else {
                for note in contact.sortedNotes {
                    let noteDate = noteTimestampFormatter.string(from: note.createdAt)
                    let source = note.source.rawValue
                    let text = note.body.replacingOccurrences(of: "\n", with: "\n  ")
                    lines.append("- [\(noteDate)] (\(source)) \(text)")
                }
            }

            lines.append("")
        }

        exportPayload = lines.joined(separator: "\n")
        exportSubject = "Contact+Notes (Readable Export)"
        showingShareSheet = true
    }

    private func clearAllData() {
        for note in notes {
            modelContext.delete(note)
        }

        for legacy in legacyCheckIns {
            modelContext.delete(legacy)
        }

        for contact in contacts {
            BirthdayReminderManager.shared.cancel(for: contact)
            modelContext.delete(contact)
        }

        try? modelContext.save()
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var subject: String? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let subject {
            controller.setValue(subject, forKey: "subject")
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
