import SwiftUI
import SwiftData
import UIKit
import AVFoundation
import Speech

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [Contact]
    @Query private var notes: [ContactNote]
    @Query private var legacyCheckIns: [CheckIn]
    @AppStorage("appColorMode") private var appColorModeRawValue = AppColorMode.system.rawValue

    @StateObject private var modelManager = WhisperModelManager.shared

    @State private var showingShareSheet = false
    @State private var exportPayload = ""
    @State private var exportSubject = "Contacts+Notes Export"
    @State private var showingClearAlert = false
    @State private var modelActionError: String?
    @State private var microphonePermissionState: SpeechPermissionState = .notDetermined
    @State private var speechRecognitionPermissionState: SpeechPermissionState = .notDetermined

    var body: some View {
        VStack(spacing: 0) {
            privacyInfoBanner

            List {
                Section("Appearance") {
                    HStack(spacing: 8) {
                        ForEach(AppColorMode.allCases) { mode in
                            Button {
                                appColorModeRawValue = mode.rawValue
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                    Text(mode.title)
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(currentColorMode == mode ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                .foregroundColor(currentColorMode == mode ? .accentColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Speech to Text") {
                    permissionRow(title: "Microphone", state: microphonePermissionState)
                    permissionRow(title: "Speech Recognition", state: speechRecognitionPermissionState)

                    if !hasRequiredSpeechPermissions {
                        Button("Allow Required Permissions") {
                            requestRequiredSpeechPermissions()
                        }
                    }

                    Button("Manage Permissions in iOS Settings") {
                        openAppSettings()
                    }

                    modelRow(
                        for: .largeV3,
                        recommended: false,
                        canDownload: hasRequiredSpeechPermissions
                    )

                    if !hasRequiredSpeechPermissions {
                        Text("Allow Microphone and Speech Recognition before downloading or using speech to text.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("To revoke permissions later, use iOS Settings.")
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
            refreshSpeechPermissionStates()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshSpeechPermissionStates()
            }
        }
    }

    private var currentColorMode: AppColorMode {
        AppColorMode(rawValue: appColorModeRawValue) ?? .system
    }

    private var hasRequiredSpeechPermissions: Bool {
        microphonePermissionState.isGranted && speechRecognitionPermissionState.isGranted
    }

    private var privacyInfoBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Privacy")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("All records are stored on this iPhone only. No cloud backend and no iCloud sync in this version.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
    }

    @ViewBuilder
    private func modelRow(
        for model: WhisperModelVariant,
        recommended: Bool,
        canDownload: Bool
    ) -> some View {
        let thisModelIsDownloading = modelManager.isDownloading(model)
        let anyModelIsDownloading = modelManager.isDownloading

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommended ? "\(model.rawValue) (Recommended)" : model.rawValue)
                Text(modelManager.fileSizeDescription(for: model))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let progress = modelManager.downloadProgressDescription(for: model) {
                    Text(progress)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let fraction = modelManager.downloadProgressFraction(for: model) {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .frame(width: 140)
                }
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
                .disabled(anyModelIsDownloading)
            } else if thisModelIsDownloading {
                Button("Cancel", role: .destructive) {
                    modelManager.cancelDownload()
                }
            } else {
                Button("Download") {
                    Task {
                        do {
                            try await modelManager.downloadModel(model)
                        } catch {
                            if !modelManager.isCancellationError(error) {
                                await MainActor.run {
                                    modelActionError = error.localizedDescription
                                }
                            }
                        }
                    }
                }
                .disabled(anyModelIsDownloading || !canDownload)
            }
        }
    }

    private func permissionRow(title: String, state: SpeechPermissionState) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(state.label, systemImage: state.icon)
                .font(.caption)
                .foregroundColor(state.color)
        }
    }

    private func refreshSpeechPermissionStates() {
        microphonePermissionState = currentMicrophonePermissionState()
        speechRecognitionPermissionState = currentSpeechRecognitionPermissionState()
    }

    private func currentMicrophonePermissionState() -> SpeechPermissionState {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        }
    }

    private func currentSpeechRecognitionPermissionState() -> SpeechPermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func requestRequiredSpeechPermissions() {
        Task {
            _ = await requestMicrophonePermission()
            _ = await requestSpeechRecognitionPermission()

            await MainActor.run {
                refreshSpeechPermissionStates()
                if !hasRequiredSpeechPermissions {
                    modelActionError = "Microphone and Speech Recognition permissions are required for speech to text."
                }
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
                "headline": note.headline ?? "",
                "summary": note.summary ?? "",
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
            exportSubject = "Contacts+Notes JSON Export"
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
        lines.append("Contacts+Notes")
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
                    let headline = (note.headline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let summary = (note.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = note.body.replacingOccurrences(of: "\n", with: "\n  ")
                    if !headline.isEmpty {
                        lines.append("- [\(noteDate)] (\(source)) \(headline)")
                        if !summary.isEmpty {
                            lines.append("  Summary: \(summary)")
                        }
                        lines.append("  \(text)")
                    } else {
                        lines.append("- [\(noteDate)] (\(source)) \(text)")
                    }
                }
            }

            lines.append("")
        }

        exportPayload = lines.joined(separator: "\n")
        exportSubject = "Contacts+Notes (Readable Export)"
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

private enum SpeechPermissionState {
    case granted
    case denied
    case notDetermined

    var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .granted:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        }
    }

    var icon: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .secondary
        }
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
