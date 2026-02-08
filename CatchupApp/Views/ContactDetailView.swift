import SwiftUI
import SwiftData
import AVFoundation
import EventKit
import UIKit

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: Contact

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    @State private var composerHeadline = ""
    @State private var composerText = ""
    @State private var composerSource: NoteSource = .typed
    @State private var isNoteComposerExpanded = true

    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var transcriptionPartialText = ""
    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var transcriptionError: String?
    @State private var transcriptionLanguage: TranscriptionLanguageOption = .englishUS
    @State private var showComposerLanguageSelector = false
    @State private var showNoteSavedFeedback = false

    @State private var reminderDraft = ""
    @State private var giftIdeaDraft = ""
    @State private var showingEventSheet = false
    @State private var eventDate: Date = Date()
    @State private var eventStatusMessage: String?

    @State private var editingNote: ContactNote?
    @State private var editHeadline = ""
    @State private var editSummary = ""
    @State private var editContent = ""
    @State private var editIsRecording = false
    @State private var editIsTranscribing = false
    @State private var editTranscriptionPartialText = ""
    @State private var editRecorder: AVAudioRecorder?
    @State private var editRecordingURL: URL?
    @State private var showEditLanguageSelector = false
    @State private var editUsedVoiceInput = false
    @FocusState private var focusedComposerField: ComposerFocusField?

    private let categoryManager = CategoryManager.shared

    private var sortedNotes: [ContactNote] {
        contact.sortedNotes
    }

    private var circleDefinition: SocialCircleDefinition {
        categoryManager.definition(for: contact.socialCircle)
    }

    var body: some View {
        List {
            Section {
                profileHeader
            }

            Section {
                noteComposerCard
            }

            Section("Reach out") {
                actionCards
            }

            Section("Reminders") {
                reminderChecklist
            }

            Section {
                giftIdeaCard
            } header: {
                HStack(spacing: 6) {
                    Text("Gift Idea")
                    Image(systemName: "gift.fill")
                }
            }

            Section("Notes Record") {
                notesTimeline
            }
        }
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
        .sheet(isPresented: $showingEventSheet) {
            eventSheet
        }
        .sheet(item: $editingNote) { _ in
            editNoteSheet
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
        .alert(
            "Calendar",
            isPresented: Binding(
                get: { eventStatusMessage != nil },
                set: { if !$0 { eventStatusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { eventStatusMessage = nil }
        } message: {
            Text(eventStatusMessage ?? "")
        }
        .onAppear {
            giftIdeaDraft = contact.giftIdea
            transcriptionLanguage = TranscriptionLanguageOption.fromCurrentLocale()
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            profileAvatar

            Text(contact.name)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)

            let line = contactLine
            if !line.isEmpty {
                Text(line)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 12) {
                if let birthday = contact.birthday {
                    HStack(spacing: 4) {
                        Image(systemName: "gift")
                        Text(birthday.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: circleDefinition.icon)
                        .foregroundColor(circleDefinition.color)
                    Text(circleDefinition.title)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    private var profileAvatar: some View {
        Group {
            if
                let data = contact.profileImageData,
                let uiImage = UIImage(data: data)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .background(Color(.secondarySystemBackground))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var noteComposerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Note", systemImage: "square.and.pencil")
                    .font(.headline)
                Spacer()
                if isRecording {
                    Text("Recording")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isNoteComposerExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isNoteComposerExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isNoteComposerExpanded {
                Divider()

                TextField("Note headline", text: $composerHeadline)
                    .fontWeight(.semibold)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedComposerField, equals: .headline)

                Divider()

                TextEditor(text: $composerText)
                    .frame(minHeight: 200)
                    .focused($focusedComposerField, equals: .body)

                if isTranscribing {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Transcribing on device...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !transcriptionPartialText.isEmpty {
                            Text(transcriptionPartialText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }

                if showComposerLanguageSelector {
                    HStack(spacing: 8) {
                        Text("Speech language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        languageChip(.englishUS, short: "ENG")
                        languageChip(.frenchFR, short: "FR")
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    // Tap mic to reveal language selector, then hold to record.
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showComposerLanguageSelector.toggle()
                        }
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(isRecording ? Color.red.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 80, pressing: { pressing in
                        if pressing {
                            if !isRecording { startRecording() }
                        } else if isRecording {
                            stopRecordingAndTranscribe()
                        }
                    }, perform: {})

                    Spacer()

                    Button("Save") {
                        saveNote()
                    }
                    .disabled(allComposerFieldsEmpty || isTranscribing)
                    .buttonStyle(.borderedProminent)
                }

                if showNoteSavedFeedback {
                    NoteSavedFeedbackView()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
        }
    }

    private var actionCards: some View {
        HStack(spacing: 10) {
            actionTile(
                title: "Call",
                systemImage: "phone.fill",
                enabled: hasPhone,
                color: .green
            ) {
                if let phone = primaryPhoneNumber {
                    openWhatsAppCall(phoneNumber: phone)
                }
            }

            actionTile(
                title: "Message",
                systemImage: "message.fill",
                enabled: hasPhone,
                color: .blue
            ) {
                if let phone = primaryPhoneNumber {
                    openWhatsAppChat(phoneNumber: phone)
                }
            }

            actionTile(
                title: "Calendar",
                systemImage: "calendar.badge.plus",
                enabled: true,
                color: .orange
            ) {
                eventDate = defaultEventDate()
                showingEventSheet = true
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func actionTile(
        title: String,
        systemImage: String,
        enabled: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(enabled ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.5)
    }

    private var reminderChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Add reminder", text: $reminderDraft)
                    .textInputAutocapitalization(.sentences)

                Button {
                    addReminder()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(reminderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !contact.sortedReminders.isEmpty {
                ForEach(contact.sortedReminders) { reminder in
                    HStack(spacing: 10) {
                        Button {
                            toggleReminder(reminder)
                        } label: {
                            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(reminder.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(reminder.title)
                            .strikethrough(reminder.isCompleted, color: .secondary)
                            .foregroundColor(reminder.isCompleted ? .secondary : .primary)

                        Spacer()

                        Button(role: .destructive) {
                            deleteReminder(reminder)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var giftIdeaCard: some View {
        TextField("Add a gift idea", text: $giftIdeaDraft)
            .textInputAutocapitalization(.sentences)
            .onChange(of: giftIdeaDraft) { _, newValue in
                contact.giftIdea = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                try? modelContext.save()
            }
            .onSubmit {
                saveGiftIdea()
            }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var notesTimeline: some View {
        if sortedNotes.isEmpty {
            Text("No notes yet")
                .foregroundColor(.secondary)
        } else {
            ForEach(sortedNotes) { note in
                let details = noteDetails(for: note)
                VStack(alignment: .leading, spacing: 3) {
                    Text(details.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(note.createdAt, style: .date)
                        Text(note.createdAt, style: .time)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEditing(note: note)
                }
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

    private var eventSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "When",
                    selection: $eventDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEventSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let date = eventDate
                        showingEventSheet = false
                        Task {
                            await createCalendarEvent(date: date)
                        }
                    }
                }
            }
        }
    }

    private var editNoteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Headline", text: $editHeadline)
                    .fontWeight(.semibold)
                    .textInputAutocapitalization(.sentences)

                Divider()

                TextField("Summary", text: $editSummary)
                    .textInputAutocapitalization(.sentences)

                Divider()

                TextEditor(text: $editContent)
                    .frame(minHeight: 220)

                if editIsTranscribing {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Transcribing on device...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !editTranscriptionPartialText.isEmpty {
                            Text(editTranscriptionPartialText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }

                if showEditLanguageSelector {
                    HStack(spacing: 8) {
                        Text("Speech language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        editLanguageChip(.englishUS, short: "ENG")
                        editLanguageChip(.frenchFR, short: "FR")
                        Spacer()
                    }
                }

                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showEditLanguageSelector.toggle()
                        }
                    } label: {
                        Image(systemName: editIsRecording ? "mic.fill" : "mic")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(editIsRecording ? Color.red.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 80, pressing: { pressing in
                        if pressing {
                            if !editIsRecording { startEditRecording() }
                        } else if editIsRecording {
                            stopEditRecordingAndTranscribe()
                        }
                    }, perform: {})

                    Spacer()
                }

                Button(role: .destructive) {
                    deleteEditingNote()
                } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            }
            .padding()
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopEditRecordingIfNeeded()
                        editingNote = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedNote()
                    }
                    .disabled(editIsTranscribing)
                }
            }
            .onDisappear {
                stopEditRecordingIfNeeded()
            }
        }
    }

    private var contactLine: String {
        [contact.phoneNumber, contact.email]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: "  •  ")
    }

    private var hasPhone: Bool {
        primaryPhoneNumber != nil
    }

    private var allComposerFieldsEmpty: Bool {
        composerHeadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var giftIdeaUnchanged: Bool {
        giftIdeaDraft.trimmingCharacters(in: .whitespacesAndNewlines) == contact.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func languageChip(_ option: TranscriptionLanguageOption, short: String) -> some View {
        Button(short) {
            transcriptionLanguage = option
            withAnimation(.easeInOut(duration: 0.15)) {
                showComposerLanguageSelector = false
            }
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(transcriptionLanguage == option ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
        .foregroundColor(transcriptionLanguage == option ? .accentColor : .secondary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
    }

    private func editLanguageChip(_ option: TranscriptionLanguageOption, short: String) -> some View {
        Button(short) {
            transcriptionLanguage = option
            withAnimation(.easeInOut(duration: 0.15)) {
                showEditLanguageSelector = false
            }
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(transcriptionLanguage == option ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
        .foregroundColor(transcriptionLanguage == option ? .accentColor : .secondary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
    }

    private func noteDetails(for note: ContactNote) -> ParsedNoteDetails {
        let title = sanitized(note.headline)
        let content = note.body.trimmingCharacters(in: .whitespacesAndNewlines)

        let fallbackHeadline: String
        if !title.isEmpty {
            fallbackHeadline = title
        } else if !content.isEmpty {
            fallbackHeadline = String(content.prefix(60))
        } else {
            fallbackHeadline = "Note"
        }

        return ParsedNoteDetails(
            headline: fallbackHeadline
        )
    }

    private func sanitized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func beginEditing(note: ContactNote) {
        editHeadline = sanitized(note.headline)
        editSummary = sanitized(note.summary)
        editContent = note.body
        editUsedVoiceInput = false
        showEditLanguageSelector = false
        editIsTranscribing = false
        editTranscriptionPartialText = ""
        editingNote = note
    }

    private func saveEditedNote() {
        guard let note = editingNote else { return }

        let trimmedHeadline = sanitized(editHeadline)
        let trimmedSummary = sanitized(editSummary)
        let trimmedContent = editContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedHeadline.isEmpty || !trimmedSummary.isEmpty || !trimmedContent.isEmpty else { return }

        let finalBody: String
        if !trimmedContent.isEmpty {
            finalBody = trimmedContent
        } else {
            finalBody = [trimmedHeadline, trimmedSummary]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        note.headline = trimmedHeadline.isEmpty ? nil : trimmedHeadline
        note.summary = trimmedSummary.isEmpty ? nil : trimmedSummary
        note.body = finalBody
        if editUsedVoiceInput {
            note.source = .voice
            note.transcriptLanguage = transcriptionLanguage.rawValue
        }
        note.updatedAt = Date()

        try? modelContext.save()
        stopEditRecordingIfNeeded()
        editUsedVoiceInput = false
        editingNote = nil
    }

    private func deleteEditingNote() {
        guard let note = editingNote else { return }
        modelContext.delete(note)
        try? modelContext.save()
        stopEditRecordingIfNeeded()
        editUsedVoiceInput = false
        editingNote = nil
    }

    private func openWhatsAppChat(phoneNumber: String) {
        let cleanNumber = phoneNumber.filter(\.isNumber)
        guard let url = URL(string: "https://wa.me/\(cleanNumber)") else { return }
        UIApplication.shared.open(url)
    }

    private func openWhatsAppCall(phoneNumber: String) {
        let cleanNumber = phoneNumber.filter(\.isNumber)
        guard let url = URL(string: "https://wa.me/\(cleanNumber)?call=1") else { return }
        UIApplication.shared.open(url)
    }

    private var primaryPhoneNumber: String? {
        firstEntry(from: contact.phoneNumber)
    }

    private func firstEntry(from raw: String?) -> String? {
        guard let raw else { return nil }
        let separators = CharacterSet(charactersIn: "•\n,;|")
        let parts = raw.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.first
    }

    private func defaultEventDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) ?? now
    }

    private func createCalendarEvent(date: Date) async {
        let eventStore = EKEventStore()

        do {
            let granted = try await requestCalendarAccess(eventStore: eventStore)
            guard granted else {
                await MainActor.run {
                    eventStatusMessage = "Calendar access is required to create events."
                }
                return
            }

            let event = EKEvent(eventStore: eventStore)
            event.title = "Reminder: connect with \(contact.name)"
            event.startDate = date
            event.endDate = Calendar.current.date(byAdding: .minute, value: 30, to: date) ?? date.addingTimeInterval(1800)
            event.calendar = eventStore.defaultCalendarForNewEvents

            var notes: [String] = []
            if let phone = contact.phoneNumber, !phone.isEmpty {
                notes.append("Phone: \(phone)")
            }
            if let email = contact.email, !email.isEmpty {
                notes.append("Email: \(email)")
            }
            event.notes = notes.joined(separator: "\n")

            try eventStore.save(event, span: .thisEvent)

            await MainActor.run {
                eventStatusMessage = "Event added to Calendar."
            }
        } catch {
            await MainActor.run {
                eventStatusMessage = "Could not create event: \(error.localizedDescription)"
            }
        }
    }

    private func requestCalendarAccess(eventStore: EKEventStore) async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    private func saveNote() {
        let trimmedHeadline = composerHeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeadline.isEmpty || !trimmedContent.isEmpty else { return }

        let body: String
        if !trimmedContent.isEmpty {
            body = trimmedContent
        } else {
            body = trimmedHeadline
        }

        let note = ContactNote(
            createdAt: Date(),
            updatedAt: Date(),
            headline: trimmedHeadline.isEmpty ? nil : trimmedHeadline,
            summary: nil,
            body: body,
            source: composerSource,
            transcriptLanguage: transcriptionLanguage.rawValue,
            audioDurationSec: nil,
            contact: contact
        )

        modelContext.insert(note)
        do {
            try modelContext.save()
            dismissComposerKeyboard()
            composerHeadline = ""
            composerText = ""
            composerSource = .typed
            triggerNoteSavedFeedback()
        } catch {
            transcriptionError = "Could not save note: \(error.localizedDescription)"
        }
    }

    private func saveGiftIdea() {
        contact.giftIdea = giftIdeaDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    private func addReminder() {
        let trimmed = reminderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reminder = ContactReminder(
            createdAt: Date(),
            title: trimmed,
            isCompleted: false,
            contact: contact
        )
        modelContext.insert(reminder)
        try? modelContext.save()

        reminderDraft = ""
    }

    private func toggleReminder(_ reminder: ContactReminder) {
        reminder.isCompleted.toggle()
        try? modelContext.save()
    }

    private func deleteReminder(_ reminder: ContactReminder) {
        modelContext.delete(reminder)
        try? modelContext.save()
    }

    private func deleteNote(_ note: ContactNote) {
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func startRecording() {
        guard hasAnyDownloadedTranscriptionModel() else {
            transcriptionError = "Voice transcription model not downloaded. Go to Settings and download a model first."
            return
        }
        transcriptionPartialText = ""

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
        transcriptionPartialText = ""
        Task {
            do {
                let text = try await WhisperOnDeviceTranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    localeIdentifier: transcriptionLanguage.rawValue,
                    onPartialResult: { partial in
                        transcriptionPartialText = partial
                    }
                )
                await MainActor.run {
                    if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        composerText = text
                    } else {
                        composerText += "\n\n\(text)"
                    }
                    composerSource = .voice
                    isTranscribing = false
                    transcriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    transcriptionError = error.localizedDescription
                    isTranscribing = false
                    transcriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }

    private func startEditRecording() {
        guard hasAnyDownloadedTranscriptionModel() else {
            transcriptionError = "Voice transcription model not downloaded. Go to Settings and download a model first."
            return
        }
        editTranscriptionPartialText = ""

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

                    self.editRecorder = recorder
                    self.editRecordingURL = url
                    self.editIsRecording = true
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

    private func stopEditRecordingAndTranscribe() {
        editRecorder?.stop()
        editRecorder = nil
        editIsRecording = false

        guard let audioURL = editRecordingURL else { return }
        editRecordingURL = nil

        editIsTranscribing = true
        editTranscriptionPartialText = ""
        Task {
            do {
                let text = try await WhisperOnDeviceTranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    localeIdentifier: transcriptionLanguage.rawValue,
                    onPartialResult: { partial in
                        editTranscriptionPartialText = partial
                    }
                )
                await MainActor.run {
                    if editContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        editContent = text
                    } else {
                        editContent += "\n\n\(text)"
                    }
                    editUsedVoiceInput = true
                    editIsTranscribing = false
                    editTranscriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    transcriptionError = error.localizedDescription
                    editIsTranscribing = false
                    editTranscriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }

    private func stopEditRecordingIfNeeded() {
        if editIsRecording {
            editRecorder?.stop()
        }
        if let audioURL = editRecordingURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        editRecorder = nil
        editRecordingURL = nil
        editIsRecording = false
        editIsTranscribing = false
        editTranscriptionPartialText = ""
    }

    private func hasAnyDownloadedTranscriptionModel() -> Bool {
        let manager = WhisperModelManager.shared
        return WhisperModelVariant.allCases.contains { manager.isModelAvailable($0) }
    }

    private func dismissComposerKeyboard() {
        focusedComposerField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func triggerNoteSavedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showNoteSavedFeedback = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                showNoteSavedFeedback = false
            }
        }
    }

}

private struct ParsedNoteDetails {
    let headline: String
}

private enum ComposerFocusField: Hashable {
    case headline
    case body
}

private struct NoteSavedFeedbackView: View {
    @State private var animate = false
    private let colors: [Color] = [.blue, .pink, .orange, .green, .purple, .yellow]
    private let xOffsets: [CGFloat] = [-52, -36, -20, -4, 12, 28, 44]

    var body: some View {
        ZStack {
            ForEach(Array(xOffsets.enumerated()), id: \.offset) { index, x in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[index % colors.count])
                    .frame(width: 4, height: 9)
                    .offset(
                        x: animate ? x : 0,
                        y: animate ? -28 - CGFloat(index % 3) * 9 : -4
                    )
                    .rotationEffect(.degrees(animate ? Double(index * 24 - 60) : 0))
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.65).delay(Double(index) * 0.02), value: animate)
            }

            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .frame(height: 44)
        .onAppear {
            animate = true
        }
    }
}
