import Foundation
import SwiftData

@Model
final class CheckIn {
    var id: UUID
    var date: Date
    var note: String
    var checkInType: CheckInType
    var contact: Contact?
    
    init(
        date: Date = Date(),
        note: String = "",
        checkInType: CheckInType = .general,
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.checkInType = checkInType
        self.contact = contact
    }
}

enum CheckInType: String, Codable, CaseIterable {
    case general = "General"
    case call = "Phone Call"
    case text = "Text"
    case meeting = "In-Person"
    case video = "Video Call"
    case email = "Email"
    
    var icon: String {
        switch self {
        case .general: return "checkmark.circle.fill"
        case .call: return "phone.fill"
        case .text: return "message.fill"
        case .meeting: return "person.2.fill"
        case .video: return "video.fill"
        case .email: return "envelope.fill"
        }
    }
    
    var color: String {
        switch self {
        case .general: return "blue"
        case .call: return "green"
        case .text: return "purple"
        case .meeting: return "orange"
        case .video: return "pink"
        case .email: return "cyan"
        }
    }
}

