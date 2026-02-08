import SwiftUI
import SwiftData
import UIKit

@main
struct CatchupApp: App {
    @UIApplicationDelegateAdaptor(CatchupAppDelegate.self) private var appDelegate
    @AppStorage("appColorMode") private var appColorModeRawValue = AppColorMode.system.rawValue

    init() {
        LocalDataProtection.applyBestEffort()
    }

    private var appColorMode: AppColorMode {
        AppColorMode(rawValue: appColorModeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appColorMode.colorScheme)
        }
        .modelContainer(for: [Contact.self, ContactNote.self, ContactReminder.self, CheckIn.self])
    }
}

final class CatchupAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            WhisperModelManager.shared.registerBackgroundSessionCompletionHandler(
                identifier: identifier,
                completionHandler: completionHandler
            )
        }
    }
}

enum AppColorMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum TranscriptionLanguageOption: String, CaseIterable, Identifiable {
    case englishUS = "en-US"
    case frenchFR = "fr-FR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .englishUS:
            return "English"
        case .frenchFR:
            return "French"
        }
    }

    static func fromCurrentLocale() -> TranscriptionLanguageOption {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code.lowercased().hasPrefix("fr") ? .frenchFR : .englishUS
    }
}

enum LocalDataProtection {
    static func applyBestEffort() {
        let fm = FileManager.default

        let urls: [URL] = [
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for url in urls {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }

            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        }
    }
}
