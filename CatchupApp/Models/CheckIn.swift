import Foundation
import SwiftData

@Model
final class CheckIn: Identifiable {
    var id: UUID
    var date: Date
    var note: String
    var title: String // Changed from checkInType to title
    var contact: Contact?
    
    init(
        date: Date = Date(),
        note: String = "",
        title: String = "Check-in",
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.title = title
        self.contact = contact
    }
}

