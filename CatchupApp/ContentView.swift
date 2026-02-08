import SwiftUI
import SwiftData
import AVFoundation

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
        contacts.count >= 5
    }

    private var completedNoteStep: Bool {
        notes.count >= 3
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
        let progress = progressFor(step)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Get started !")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(step.title)
                .font(.headline)

            ProgressView(value: Double(progress.current), total: Double(progress.goal))

            Text("\(progress.current)/\(progress.goal) completed")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Step \(step.stepNumber) of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    private func progressFor(_ step: OnboardingStep) -> (current: Int, goal: Int) {
        switch step {
        case .addContact:
            return (min(contacts.count, 5), 5)
        case .recordNote:
            return (min(notes.count, 3), 3)
        case .addGiftIdea:
            let count = contacts.filter { !$0.giftIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            return (min(count, 1), 1)
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
            return "Add 5 contacts"
        case .recordNote:
            return "Record 3 notes"
        case .addGiftIdea:
            return "Add a gift idea"
        }
    }

    var subtitle: String {
        switch self {
        case .addContact:
            return "Import contacts from your address book."
        case .recordNote:
            return "Create notes to build your relationship memory."
        case .addGiftIdea:
            return "Add a gift idea on one profile to complete setup."
        }
    }
}

private struct QuickNoteComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name, order: .forward) private var contacts: [Contact]

    @State private var selectedContactID: UUID?
    @State private var noteHeadline = ""
    @State private var noteText = ""
    @State private var transcriptionLanguage: TranscriptionLanguageOption = .englishUS
    @State private var showLanguageSelector = false
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var transcriptionPartialText = ""
    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
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
                    TextField("Note headline", text: $noteHeadline)
                        .fontWeight(.semibold)
                        .textInputAutocapitalization(.sentences)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)

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

                    if showLanguageSelector {
                        HStack(spacing: 8) {
                            Text("Speech language")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            languageChip(.englishUS, short: "ENG")
                            languageChip(.frenchFR, short: "FR")
                            Spacer()
                        }
                    }

                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showLanguageSelector.toggle()
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
                    }
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
                        (noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         noteHeadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                        isTranscribing
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
                transcriptionLanguage = TranscriptionLanguageOption.fromCurrentLocale()
            }
            .onDisappear {
                if isRecording {
                    recorder?.stop()
                    recorder = nil
                    isRecording = false
                }
                transcriptionPartialText = ""
            }
        }
    }

    private var selectedContact: Contact? {
        guard let selectedContactID else { return nil }
        return contacts.first(where: { $0.id == selectedContactID })
    }

    private func languageChip(_ option: TranscriptionLanguageOption, short: String) -> some View {
        Button(short) {
            transcriptionLanguage = option
            withAnimation(.easeInOut(duration: 0.15)) {
                showLanguageSelector = false
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

    private func save() {
        let trimmedHeadline = noteHeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeadline.isEmpty || !trimmed.isEmpty else { return }
        guard let selectedContact else {
            composerError = "Please select a contact."
            return
        }

        let body: String
        if !trimmed.isEmpty {
            body = trimmed
        } else {
            body = trimmedHeadline
        }

        let note = ContactNote(
            createdAt: Date(),
            updatedAt: Date(),
            headline: trimmedHeadline.isEmpty ? nil : trimmedHeadline,
            summary: nil,
            body: body,
            source: .typed,
            transcriptLanguage: transcriptionLanguage.rawValue,
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

    private func startRecording() {
        guard hasAnyDownloadedTranscriptionModel() else {
            composerError = "Voice transcription model not downloaded. Go to Settings and download a model first."
            return
        }
        transcriptionPartialText = ""

        let session = AVAudioSession.sharedInstance()

        let permissionHandler: (Bool) -> Void = { granted in
            guard granted else {
                DispatchQueue.main.async {
                    composerError = "Microphone access is required to use speech-to-text."
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
                    composerError = "Could not start recording: \(error.localizedDescription)"
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: permissionHandler)
        } else {
            session.requestRecordPermission(permissionHandler)
        }
    }

    private func hasAnyDownloadedTranscriptionModel() -> Bool {
        let manager = WhisperModelManager.shared
        return WhisperModelVariant.allCases.contains { manager.isModelAvailable($0) }
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
                    if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        noteText = text
                    } else {
                        noteText += "\n\n\(text)"
                    }
                    isTranscribing = false
                    transcriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    composerError = error.localizedDescription
                    isTranscribing = false
                    transcriptionPartialText = ""
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
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
