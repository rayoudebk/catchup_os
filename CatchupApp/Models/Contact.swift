import Foundation
import SwiftData

enum SocialCircle: String, Codable, CaseIterable {
    case personal
    case family
    case friends
    case work
    case other

    init(legacyRawValue: String?) {
        let value = (legacyRawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "personal":
            self = .personal
        case "family":
            self = .family
        case "friends", "friend":
            self = .friends
        case "work", "professional":
            self = .work
        case "", "unknown":
            self = .personal
        default:
            self = .other
        }
    }

    var title: String {
        switch self {
        case .personal:
            return "Personal"
        case .family:
            return "Family"
        case .friends:
            return "Friends"
        case .work:
            return "Work"
        case .other:
            return "Other"
        }
    }
}

@Model
final class Contact {
    var id: UUID
    var name: String
    var phoneNumber: String?
    var email: String?
    var birthday: Date?
    var birthdayNote: String
    var giftIdea: String

    // Maps from older schema where this field was named "category".
    @Attribute(originalName: "category")
    var socialCircleRawValue: String

    var isFavorite: Bool
    var profileImageData: Data?
    var contactIdentifier: String?
    var createdAt: Date

    // Legacy plain-text note field from previous schema. We migrate this into ContactNote.
    @Attribute(originalName: "notes")
    var legacyPlainText: String

    @Relationship(deleteRule: .cascade, inverse: \ContactNote.contact)
    var noteTimeline: [ContactNote]?

    init(
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        birthday: Date? = nil,
        birthdayNote: String = "",
        giftIdea: String = "",
        socialCircle: SocialCircle = .personal,
        isFavorite: Bool = false,
        profileImageData: Data? = nil,
        contactIdentifier: String? = nil,
        createdAt: Date = Date(),
        legacyPlainText: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.birthday = birthday
        self.birthdayNote = birthdayNote
        self.giftIdea = giftIdea
        self.socialCircleRawValue = socialCircle.rawValue
        self.isFavorite = isFavorite
        self.profileImageData = profileImageData
        self.contactIdentifier = contactIdentifier
        self.createdAt = createdAt
        self.legacyPlainText = legacyPlainText
        self.noteTimeline = []
    }

    var socialCircle: SocialCircle {
        get {
            let normalized = SocialCircle(legacyRawValue: socialCircleRawValue)
            if socialCircleRawValue != normalized.rawValue {
                socialCircleRawValue = normalized.rawValue
            }
            return normalized
        }
        set {
            socialCircleRawValue = newValue.rawValue
        }
    }

    var notes: [ContactNote]? {
        get { noteTimeline }
        set { noteTimeline = newValue }
    }

    var sortedNotes: [ContactNote] {
        (noteTimeline ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var latestNote: ContactNote? {
        sortedNotes.first
    }
}
