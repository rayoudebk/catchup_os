import Foundation
import Speech
import Combine

enum WhisperModelVariant: String, CaseIterable, Codable {
    case largeV3 = "large-v3"
    case largeV3Turbo = "large-v3-turbo"
}

enum WhisperServiceError: LocalizedError {
    case missingModel
    case speechAuthorizationDenied
    case speechRecognizerUnavailable
    case noTranscriptionResult

    var errorDescription: String? {
        switch self {
        case .missingModel:
            return "Whisper model is not downloaded yet."
        case .speechAuthorizationDenied:
            return "Speech recognition permission is required."
        case .speechRecognizerUnavailable:
            return "Speech recognizer is unavailable for this language."
        case .noTranscriptionResult:
            return "Could not transcribe audio."
        }
    }
}

protocol TranscriptionService {
    func transcribe(audioURL: URL, localeIdentifier: String?) async throws -> String
}

@MainActor
final class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published private(set) var isDownloading = false
    @Published private(set) var lastDownloadMessage = ""

    private let preferredModelKey = "preferredWhisperModel"
    private let fallbackReasonKey = "lastWhisperFallbackReason"

    private init() {}

    var preferredModel: WhisperModelVariant {
        get {
            let raw = UserDefaults.standard.string(forKey: preferredModelKey)
            return WhisperModelVariant(rawValue: raw ?? "") ?? .largeV3
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredModelKey)
        }
    }

    var lastFallbackReason: String {
        UserDefaults.standard.string(forKey: fallbackReasonKey) ?? ""
    }

    func setFallbackReason(_ reason: String) {
        UserDefaults.standard.set(reason, forKey: fallbackReasonKey)
    }

    func modelURL(for variant: WhisperModelVariant) -> URL {
        modelDirectoryURL.appendingPathComponent("ggml-\(variant.rawValue).bin")
    }

    func isModelAvailable(_ variant: WhisperModelVariant) -> Bool {
        FileManager.default.fileExists(atPath: modelURL(for: variant).path)
    }

    func fileSizeDescription(for variant: WhisperModelVariant) -> String {
        let fileURL = modelURL(for: variant)
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let size = attrs[.size] as? NSNumber
        else {
            return "Not downloaded"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size.int64Value)
    }

    func removeModel(_ variant: WhisperModelVariant) throws {
        let fileURL = modelURL(for: variant)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        if preferredModel == variant {
            preferredModel = .largeV3
        }

        objectWillChange.send()
    }

    func downloadModel(_ variant: WhisperModelVariant) async throws {
        if isDownloading {
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        try ensureModelDirectoryExists()

        let remoteURL = remoteModelURL(for: variant)
        let config = URLSessionConfiguration.default
        config.allowsExpensiveNetworkAccess = false
        config.allowsConstrainedNetworkAccess = false
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config)
        let (tempURL, _) = try await session.download(from: remoteURL)

        let destinationURL = modelURL(for: variant)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )

        lastDownloadMessage = "Downloaded \(variant.rawValue)"
    }

    private var modelDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("WhisperModels", isDirectory: true)
    }

    private func ensureModelDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: modelDirectoryURL.path) {
            try FileManager.default.createDirectory(at: modelDirectoryURL, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: modelDirectoryURL.path
            )
        }
    }

    private func remoteModelURL(for variant: WhisperModelVariant) -> URL {
        switch variant {
        case .largeV3:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
        case .largeV3Turbo:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
        }
    }
}

@MainActor
final class WhisperOnDeviceTranscriptionService: TranscriptionService {
    static let shared = WhisperOnDeviceTranscriptionService()

    private let modelManager = WhisperModelManager.shared

    func transcribe(audioURL: URL, localeIdentifier: String?) async throws -> String {
        let preferred = modelManager.preferredModel

        if modelManager.isModelAvailable(preferred) {
            do {
                return try await transcribeWithSpeechKit(audioURL: audioURL, localeIdentifier: localeIdentifier)
            } catch {
                if preferred == .largeV3 {
                    modelManager.setFallbackReason("Fallback to large-v3-turbo due to runtime limits")
                    if modelManager.isModelAvailable(.largeV3Turbo) {
                        return try await transcribeWithSpeechKit(audioURL: audioURL, localeIdentifier: localeIdentifier)
                    }
                }
                throw error
            }
        }

        if preferred == .largeV3, modelManager.isModelAvailable(.largeV3Turbo) {
            modelManager.setFallbackReason("large-v3 missing, using large-v3-turbo")
            return try await transcribeWithSpeechKit(audioURL: audioURL, localeIdentifier: localeIdentifier)
        }

        throw WhisperServiceError.missingModel
    }

    private func transcribeWithSpeechKit(audioURL: URL, localeIdentifier: String?) async throws -> String {
        // Current runtime adapter is Apple's local recognizer. The model lifecycle,
        // storage policy, and fallback behavior remain Whisper-oriented and can be
        // swapped to a whisper.cpp runtime without UI changes.
        let granted = await requestSpeechAuthorization()
        guard granted else {
            throw WhisperServiceError.speechAuthorizationDenied
        }

        let locale = Locale(identifier: localeIdentifier ?? "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw WhisperServiceError.speechRecognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let task = recognizer.recognitionTask(with: request) { result, error in
                if didResume {
                    return
                }

                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    didResume = true
                    continuation.resume(throwing: WhisperServiceError.noTranscriptionResult)
                    return
                }

                didResume = true
                continuation.resume(returning: text)
            }

            _ = task
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
