import SwiftUI
import SwiftData
import AVFoundation

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: Contact

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    @State private var composerText = ""
    @State private var composerSource: NoteSource = .typed
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var transcriptionError: String?

    private let categoryManager = CategoryManager.shared

    private var sortedNotes: [ContactNote] {
        contact.sortedNotes
    }

    var body: some View {
        List {
            Section {
                headerCard
            }

            Section("New Note") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $composerText)
                        .frame(minHeight: 120)

                    if isTranscribing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Transcribing on device...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Button {
                            toggleRecording()
                        } label: {
                            Label(
                                isRecording ? "Stop Recording" : "Record Voice",
                                systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
                            )
                            .foregroundColor(isRecording ? .red : .blue)
                        }

                        Spacer()

                        Button("Save Note") {
                            saveNote()
                        }
                        .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranscribing)
                    }
                }
            }

            Section("Timeline") {
                if sortedNotes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(note.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(note.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                noteSourceBadge(note.source)
                            }

                            Text(note.body)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteNote(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Contact", systemImage: "pencil")
                    }

                    Button {
                        contact.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            contact.isFavorite ? "Remove Favorite" : "Mark Favorite",
                            systemImage: contact.isFavorite ? "star.slash" : "star"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Contact", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: contact)
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                BirthdayReminderManager.shared.cancel(for: contact)
                modelContext.delete(contact)
                try? modelContext.save()
            }
        } message: {
            Text("This removes the contact and all associated notes.")
        }
        .alert(
            "Transcription Error",
            isPresented: Binding(
                get: { transcriptionError != nil },
                set: { if !$0 { transcriptionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { transcriptionError = nil }
        } message: {
            Text(transcriptionError ?? "")
        }
    }

    private var headerCard: some View {
        let circle = categoryManager.definition(for: contact.socialCircle)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let phone = contact.phoneNumber, !phone.isEmpty {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let email = contact.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if contact.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: circle.icon)
                    .foregroundColor(circle.color)
                Text(circle.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let birthday = contact.birthday {
                Divider()

                HStack {
                    Label("Birthday", systemImage: "gift.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(birthday.formatted(date: .abbreviated, time: .omitted))
                }

                if !contact.birthdayNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(contact.birthdayNote)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if !contact.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                Text("Gift Idea")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(contact.giftIdea)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func noteSourceBadge(_ source: NoteSource) -> some View {
        switch source {
        case .typed:
            Text("typed")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .voice:
            Text("voice")
                .font(.caption2)
                .foregroundColor(.blue)
        case .migratedLegacy:
            Text("legacy")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }

    private func saveNote() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = ContactNote(
            createdAt: Date(),
            updatedAt: Date(),
            body: trimmed,
            source: composerSource,
            transcriptLanguage: Locale.current.identifier,
            audioDurationSec: nil,
            contact: contact
        )

        modelContext.insert(note)
        try? modelContext.save()

        composerText = ""
        composerSource = .typed
    }

    private func deleteNote(_ note: ContactNote) {
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func toggleRecording() {
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        let permissionHandler: (Bool) -> Void = { granted in
            guard granted else {
                DispatchQueue.main.async {
                    transcriptionError = "Microphone access is required to record voice notes."
                }
                return
            }

            DispatchQueue.main.async {
                do {
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try session.setActive(true)

                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("m4a")

                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44_100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.record()

                    self.recorder = recorder
                    self.recordingURL = url
                    self.isRecording = true
                } catch {
                    transcriptionError = "Could not start recording: \(error.localizedDescription)"
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: permissionHandler)
        } else {
            session.requestRecordPermission(permissionHandler)
        }
    }

    private func stopRecordingAndTranscribe() {
        recorder?.stop()
        recorder = nil
        isRecording = false

        guard let audioURL = recordingURL else { return }

        isTranscribing = true
        Task {
            do {
                let text = try await WhisperOnDeviceTranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    localeIdentifier: Locale.current.identifier
                )
                await MainActor.run {
                    if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        composerText = text
                    } else {
                        composerText += "\n\n\(text)"
                    }
                    composerSource = .voice
                    isTranscribing = false
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    transcriptionError = error.localizedDescription
                    isTranscribing = false
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }
}
