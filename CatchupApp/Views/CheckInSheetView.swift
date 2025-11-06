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
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            Button {
                                if isRecording {
                                    speechRecognizer.stopRecording()
                                    isRecording = false
                                } else {
                                    speechRecognizer.startRecording { result in
                                        note = result
                                    }
                                    isRecording = true
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
                    }
                }
                
                Section("AI Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI-generated summary will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        
                        Text("Using on-device Apple Intelligence 🔒 to extract structured insights from your notes. Your notes stay private.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
}

// Speech Recognition Helper
class SpeechRecognizer {
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
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
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
}

