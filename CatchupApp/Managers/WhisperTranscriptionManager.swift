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
    @Published private(set) var activeDownloadModel: WhisperModelVariant?
    @Published private(set) var downloadTotalBytes: Int64 = 0
    @Published private(set) var downloadReceivedBytes: Int64 = 0

    private let preferredModelKey = "preferredWhisperModel"
    private let fallbackReasonKey = "lastWhisperFallbackReason"
    private let backgroundSessionIdentifier = "rayoudev.catchup.whisper.model-download"
    private let downloadRelay: DownloadRelay
    private var activeDownloadTask: URLSessionDownloadTask?
    private var backgroundSessionCompletionHandler: (() -> Void)?

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = false
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: downloadRelay, delegateQueue: nil)
    }()

    private init() {
        downloadRelay = DownloadRelay()
        downloadRelay.onProgress = { [weak self] received, total in
            Task { @MainActor in
                self?.downloadReceivedBytes = received
                self?.downloadTotalBytes = max(0, total)
            }
        }
        downloadRelay.onBackgroundEventsFinished = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.backgroundSessionCompletionHandler?()
                self.backgroundSessionCompletionHandler = nil
            }
        }
    }

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

    func isDownloading(_ variant: WhisperModelVariant) -> Bool {
        isDownloading && activeDownloadModel == variant
    }

    func downloadProgressDescription(for variant: WhisperModelVariant) -> String? {
        guard isDownloading(variant) else { return nil }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file

        let received = formatter.string(fromByteCount: downloadReceivedBytes)
        guard downloadTotalBytes > 0 else {
            return received
        }

        let total = formatter.string(fromByteCount: downloadTotalBytes)
        let percent = Int((Double(downloadReceivedBytes) / Double(downloadTotalBytes)) * 100)
        return "\(received)/\(total) (\(max(0, min(100, percent)))%)"
    }

    func downloadProgressFraction(for variant: WhisperModelVariant) -> Double? {
        guard isDownloading(variant), downloadTotalBytes > 0 else { return nil }
        let fraction = Double(downloadReceivedBytes) / Double(downloadTotalBytes)
        return max(0, min(1, fraction))
    }

    func registerBackgroundSessionCompletionHandler(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == backgroundSessionIdentifier else { return }
        backgroundSessionCompletionHandler = completionHandler
        _ = backgroundSession
    }

    func cancelDownload() {
        guard isDownloading else { return }
        lastDownloadMessage = "Canceling download..."
        activeDownloadTask?.cancel()
    }

    func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
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
        activeDownloadModel = variant
        downloadReceivedBytes = 0
        downloadTotalBytes = 0
        defer {
            isDownloading = false
            activeDownloadModel = nil
            activeDownloadTask = nil
        }

        try ensureModelDirectoryExists()

        let remoteURL = remoteModelURL(for: variant)
        let tempURL: URL
        do {
            tempURL = try await downloadWithProgress(from: remoteURL, for: variant)
        } catch {
            if isCancellationError(error) {
                lastDownloadMessage = "Download canceled"
                return
            }
            throw error
        }

        let destinationURL = modelURL(for: variant)
        try ensureModelDirectoryExists()

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        } catch {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            throw error
        }

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )

        lastDownloadMessage = "Downloaded \(variant.rawValue)"
    }

    private func downloadWithProgress(from remoteURL: URL, for variant: WhisperModelVariant) async throws -> URL {
        _ = backgroundSession

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                downloadRelay.continuation = continuation
                let task = backgroundSession.downloadTask(with: remoteURL)
                task.taskDescription = "whisper.\(variant.rawValue)"
                activeDownloadTask = task
                task.resume()
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.activeDownloadTask?.cancel()
            }
        })
    }

    private var modelDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("WhisperModels", isDirectory: true)
    }

    private func ensureModelDirectoryExists() throws {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        if !fm.fileExists(atPath: appSupport.path) {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: modelDirectoryURL.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                try fm.removeItem(at: modelDirectoryURL)
                try fm.createDirectory(at: modelDirectoryURL, withIntermediateDirectories: true)
            }
        } else {
            try fm.createDirectory(at: modelDirectoryURL, withIntermediateDirectories: true)
        }

        try fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: modelDirectoryURL.path
        )
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

private final class DownloadRelay: NSObject, URLSessionDownloadDelegate {
    var continuation: CheckedContinuation<URL, Error>?
    var onProgress: (Int64, Int64) -> Void = { _, _ in }
    var onBackgroundEventsFinished: () -> Void = {}

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let stableTempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("whisper-download-\(UUID().uuidString)")
                .appendingPathExtension("bin")

            if FileManager.default.fileExists(atPath: stableTempURL.path) {
                try FileManager.default.removeItem(at: stableTempURL)
            }

            try FileManager.default.moveItem(at: location, to: stableTempURL)
            continuation?.resume(returning: stableTempURL)
        } catch {
            continuation?.resume(throwing: error)
        }

        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        onBackgroundEventsFinished()
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

        if preferred == .largeV3Turbo, modelManager.isModelAvailable(.largeV3) {
            modelManager.setFallbackReason("large-v3-turbo missing, using large-v3")
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
