import SwiftUI
import SwiftData

@main
struct CatchupApp: App {
    init() {
        LocalDataProtection.applyBestEffort()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Contact.self, ContactNote.self, CheckIn.self])
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
