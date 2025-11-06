import SwiftUI
import SwiftData

@main
struct CatchupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Contact.self, CheckIn.self, CustomCategory.self])
    }
}

