import SwiftUI
import SwiftData
import Speech
import AVFoundation

struct CheckInSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let contact: Contact
    var checkIn: CheckIn? = nil // Optional for editing
    
    @State private var title = ""
    @State private var note = ""
    @State private var checkInDate = Date()
    @State private var isRecording = false
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isGeneratingSummary = false
    @State private var lastAISummary: String? = nil
    @AppStorage("selectedSpeechLanguage") private var selectedSpeechLanguage = "en-US"
    @State private var showingLanguageSelector = false
    
    init(contact: Contact, checkIn: CheckIn? = nil) {
        self.contact = contact
        self.checkIn = checkIn
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker("Check-in Date", selection: $checkInDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("Title") {
                    TextField("What stood out from your check-in?", text: $title)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        // Language selector - shown above mic button when tapped
                        if showingLanguageSelector {
                            HStack {
                                Spacer()
                                LanguageSelectorView(
                                    selectedLanguage: $selectedSpeechLanguage,
                                    onDismiss: {
                                        showingLanguageSelector = false
                                    }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            
                            // Language button - tap to show language selector above mic
                            Button {
                                showingLanguageSelector.toggle()
                            } label: {
                                Text(currentLanguageDisplay)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            // Mic button
                            Button {
                                if isRecording {
                                    speechRecognizer.stopRecording()
                                    isRecording = false
                                } else {
                                    speechRecognizer.setLanguage(selectedSpeechLanguage)
                                    speechRecognizer.startRecording { result in
                                        note = result
                                    }
                                    isRecording = true
                                    showingLanguageSelector = false
                                }
                            } label: {
                                Image(systemName: isRecording ? "mic.fill" : "mic")
                                    .foregroundColor(isRecording ? .red : .blue)
                                    .font(.title3)
                            }
                        }
                        
                    TextEditor(text: $note)
                        .frame(height: 120)
                    
                    Text("Add details about your conversation or interaction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if lastAISummary != nil {
                            Text("Apple Intelligence draft applied")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("AI Summary (coming soon)")
                                .font(.headline)
                            Spacer()
                            if isGeneratingSummary {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.blue)
                            }
                            Button {
                                generateAISummary()
                            } label: {
                                Image(systemName: "infinity")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingSummary)
                            .accessibilityLabel("Summarize with Apple Intelligence")
                        }
                        
                        Text("We’re building a deeper Apple Intelligence summary here. For now, use the button to draft quick highlights from your notes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle(checkIn == nil ? "Record Check-in" : "Edit Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let checkIn = checkIn {
                    title = checkIn.title
                    note = checkIn.note
                    checkInDate = checkIn.date
                }
                speechRecognizer.setLanguage(selectedSpeechLanguage)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCheckIn()
                    }
                }
            }
        }
    }
    
    private func saveCheckIn() {
        if let existingCheckIn = checkIn {
            // Update existing check-in
            existingCheckIn.title = title.isEmpty ? "Check-in" : title
            existingCheckIn.note = note
            existingCheckIn.date = checkInDate
        } else {
            // Create new check-in
            let newCheckIn = CheckIn(
            date: checkInDate,
            note: note,
                title: title.isEmpty ? "Check-in" : title,
            contact: contact
        )
            modelContext.insert(newCheckIn)
        contact.lastCheckInDate = checkInDate
        }
        
        // Reschedule notification
        NotificationManager.shared.scheduleNotification(for: contact)
        
        dismiss()
    }
    
    private func generateAISummary() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        lastAISummary = nil
        
        let originalNote = note
        DispatchQueue.global(qos: .userInitiated).async {
            let summary = buildSummary(from: trimmed)
            let augmentedText = "\(originalNote)\n\nApple Intelligence summary:\n\(summary)"
            DispatchQueue.main.async {
                note = augmentedText
                lastAISummary = summary
                isGeneratingSummary = false
            }
        }
    }
    
    private var currentLanguageDisplay: String {
        let locale = Locale(identifier: selectedSpeechLanguage)
        return locale.language.languageCode?.identifier.uppercased() ?? "EN"
    }
    
    private func buildSummary(from text: String) -> String {
        // Simple heuristic summary: extract key sentences and highlights
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if sentences.isEmpty {
            return text
        }
        var bulletPoints: [String] = []
        for sentence in sentences.prefix(3) {
            let formatted = sentence.prefix(1).uppercased() + sentence.dropFirst()
            bulletPoints.append("• \(formatted)")
        }
        let highlight = sentences.first ?? text
        return (["Key points:"] + bulletPoints + ["Highlight: \(highlight)"]).joined(separator: "\n")
    }
}

// Language Selector Component
struct LanguageSelectorView: View {
    @Binding var selectedLanguage: String
    let onDismiss: () -> Void
    
    var availableLanguages: [(identifier: String, displayName: String)] {
        let userPreferredLanguages = Locale.preferredLanguages
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        var languages: [(identifier: String, displayName: String)] = []
        var languageCodesAdded = Set<String>()
        
        // Get languages from user's preferred languages that are supported
        for preferredLang in userPreferredLanguages {
            let locale = Locale(identifier: preferredLang)
            if supportedLocales.contains(locale) {
                let languageCode = locale.language.languageCode?.identifier ?? ""
                let countryCode = locale.region?.identifier ?? ""
                let identifier = countryCode.isEmpty ? languageCode : "\(languageCode)-\(countryCode)"
                
                // Use 2-letter language code (EN, FR, PT, ES, etc.)
                let displayName = languageCode.uppercased()
                
                if !languages.contains(where: { $0.identifier == identifier }) {
                    languages.append((identifier: identifier, displayName: displayName))
                    languageCodesAdded.insert(languageCode.lowercased())
                }
            }
        }
        
        // Always add common languages if not already present
        let commonLanguages = [
            ("en-US", "EN", "en"),
            ("fr-FR", "FR", "fr"),
            ("es-ES", "ES", "es"),
            ("pt-PT", "PT", "pt")
        ]
        
        for (identifier, displayName, code) in commonLanguages {
            if !languageCodesAdded.contains(code) {
                let locale = Locale(identifier: identifier)
                if supportedLocales.contains(locale) {
                    languages.append((identifier: identifier, displayName: displayName))
                    languageCodesAdded.insert(code)
                }
            }
        }
        
        // If still no languages found, add common ones anyway
        if languages.isEmpty {
            languages = [
                ("en-US", "EN"),
                ("fr-FR", "FR"),
                ("es-ES", "ES"),
                ("pt-PT", "PT")
            ]
        }
        
        return languages
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(availableLanguages, id: \.identifier) { language in
                Button {
                    selectedLanguage = language.identifier
                    onDismiss()
                } label: {
                    Text(language.displayName)
                        .font(.caption)
                        .fontWeight(selectedLanguage == language.identifier ? .bold : .regular)
                        .foregroundColor(selectedLanguage == language.identifier ? .white : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedLanguage == language.identifier ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

// Speech Recognition Helper
class SpeechRecognizer {
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func setLanguage(_ languageIdentifier: String) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageIdentifier))
    }
    
    func startRecording(completion: @escaping (String) -> Void) {
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                guard authStatus == .authorized else { return }
                self.record(completion: completion)
            }
        }
    }
    
    private func record(completion: @escaping (String) -> Void) {
        // Stop and clean up any existing recording first
        stopRecording()
        
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        // Ensure engine is stopped and tap is removed before installing new one
        // Stopping the engine automatically removes taps
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap if it exists (removeTap doesn't throw, but check if engine is running first)
        if audioEngine.isRunning {
            inputNode.removeTap(onBus: 0)
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                completion(transcription)
            }
            
            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        
        // Remove tap and clean up
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}

// Record Check-In Sheet with Contact Dropdown
struct RecordCheckInSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let contacts: [Contact]
    
    @State private var selectedContact: Contact?
    @State private var title = ""
    @State private var note = ""
    @State private var checkInDate = Date()
    @State private var isRecording = false
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isGeneratingSummary = false
    @State private var lastAISummary: String? = nil
    @AppStorage("selectedSpeechLanguage") private var selectedSpeechLanguage = "en-US"
    @State private var showingLanguageSelector = false
    
    private var currentLanguageDisplay: String {
        let locale = Locale(identifier: selectedSpeechLanguage)
        return locale.language.languageCode?.identifier.uppercased() ?? "EN"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    Picker("Select Contact", selection: $selectedContact) {
                        Text("Select a contact").tag(nil as Contact?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(contact as Contact?)
                        }
                    }
                }
                
                Section("Date & Time") {
                    DatePicker("Check-in Date", selection: $checkInDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("Title") {
                    TextField("What stood out from your check-in?", text: $title)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        // Language selector - shown above mic button when tapped
                        if showingLanguageSelector {
                            HStack {
                                Spacer()
                                LanguageSelectorView(
                                    selectedLanguage: $selectedSpeechLanguage,
                                    onDismiss: {
                                        showingLanguageSelector = false
                                    }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            
                            // Language button - tap to show language selector above mic
                            Button {
                                showingLanguageSelector.toggle()
                            } label: {
                                Text(currentLanguageDisplay)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            // Mic button
                            Button {
                                if isRecording {
                                    speechRecognizer.stopRecording()
                                    isRecording = false
                                } else {
                                    speechRecognizer.setLanguage(selectedSpeechLanguage)
                                    speechRecognizer.startRecording { result in
                                        note = result
                                    }
                                    isRecording = true
                                    showingLanguageSelector = false
                                }
                            } label: {
                                Image(systemName: isRecording ? "mic.fill" : "mic")
                                    .foregroundColor(isRecording ? .red : .blue)
                                    .font(.title3)
                            }
                        }
                        
                        TextEditor(text: $note)
                            .frame(height: 120)
                        
                        Text("Add details about your conversation or interaction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        if lastAISummary != nil {
                            Text("Apple Intelligence draft applied")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("AI Summary (coming soon)")
                                .font(.headline)
                            Spacer()
                            if isGeneratingSummary {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.blue)
                            }
                            Button {
                                generateAISummary()
                            } label: {
                                Image(systemName: "infinity")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingSummary)
                            .accessibilityLabel("Summarize with Apple Intelligence")
                        }
                        
                        Text("We're building a deeper Apple Intelligence summary here. For now, use the button to draft quick highlights from your notes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Record Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                speechRecognizer.setLanguage(selectedSpeechLanguage)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCheckIn()
                    }
                    .disabled(selectedContact == nil)
                }
            }
        }
    }
    
    private func saveCheckIn() {
        guard let contact = selectedContact else { return }
        
        let newCheckIn = CheckIn(
            date: checkInDate,
            note: note,
            title: title.isEmpty ? "Check-in" : title,
            contact: contact
        )
        modelContext.insert(newCheckIn)
        contact.lastCheckInDate = checkInDate
        
        // Reschedule notification
        NotificationManager.shared.scheduleNotification(for: contact)
        
        dismiss()
    }
    
    private func generateAISummary() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        lastAISummary = nil
        
        let originalNote = note
        DispatchQueue.global(qos: .userInitiated).async {
            let summary = buildSummary(from: trimmed)
            let augmentedText = "\(originalNote)\n\nApple Intelligence summary:\n\(summary)"
            DispatchQueue.main.async {
                note = augmentedText
                lastAISummary = summary
                isGeneratingSummary = false
            }
        }
    }
    
    private func buildSummary(from text: String) -> String {
        // Simple heuristic summary: extract key sentences and highlights
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if sentences.isEmpty {
            return text
        }
        var bulletPoints: [String] = []
        for sentence in sentences.prefix(3) {
            let formatted = sentence.prefix(1).uppercased() + sentence.dropFirst()
            bulletPoints.append("• \(formatted)")
        }
        let highlight = sentences.first ?? text
        return (["Key points:"] + bulletPoints + ["Highlight: \(highlight)"]).joined(separator: "\n")
    }
}

