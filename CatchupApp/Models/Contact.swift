import Foundation
import SwiftData

@Model
final class Contact {
    var id: UUID
    var name: String
    var phoneNumber: String?
    var email: String?
    var category: ContactCategory
    var frequencyDays: Int
    var preferredDayOfWeek: Int? // 1 = Sunday, 7 = Saturday
    var preferredHour: Int? // 0-23
    var lastCheckInDate: Date?
    var notes: String
    var isFavorite: Bool
    var createdAt: Date
    var reminders: [String] // Checklist items
    var giftIdea: String // Next gift idea
    var photosPersonLocalIdentifier: String? // Link to Photos app person
    var birthday: Date? // Birthday from contacts
    var profileImageData: Data? // Profile image from contacts
    var contactIdentifier: String? // Original CNContact identifier
    
    @Relationship(deleteRule: .cascade, inverse: \CheckIn.contact)
    var checkIns: [CheckIn]?
    
    init(
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        category: ContactCategory = .personal,
        frequencyDays: Int = 30, // Default to monthly
        preferredDayOfWeek: Int? = nil,
        preferredHour: Int? = nil,
        notes: String = "",
        isFavorite: Bool = false,
        reminders: [String] = [],
        giftIdea: String = "",
        photosPersonLocalIdentifier: String? = nil,
        birthday: Date? = nil,
        profileImageData: Data? = nil,
        contactIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.category = category
        self.frequencyDays = frequencyDays
        self.preferredDayOfWeek = preferredDayOfWeek
        self.preferredHour = preferredHour
        self.notes = notes
        self.isFavorite = isFavorite
        self.reminders = reminders
        self.giftIdea = giftIdea
        self.photosPersonLocalIdentifier = photosPersonLocalIdentifier
        self.birthday = birthday
        self.profileImageData = profileImageData
        self.contactIdentifier = contactIdentifier
        self.createdAt = Date()
        self.checkIns = []
    }
    
    var daysUntilNextCheckIn: Int {
        guard let lastCheckIn = lastCheckInDate else {
            return 0 // Overdue - no check-in yet
        }
        
        let daysSinceLastCheckIn = Calendar.current.dateComponents(
            [.day],
            from: lastCheckIn,
            to: Date()
        ).day ?? 0
        
        return max(0, frequencyDays - daysSinceLastCheckIn)
    }
    
    var isOverdue: Bool {
        daysUntilNextCheckIn == 0
    }
    
    var nextCheckInDate: Date? {
        guard let lastCheckIn = lastCheckInDate else {
            return Date()
        }
        return Calendar.current.date(byAdding: .day, value: frequencyDays, to: lastCheckIn)
    }
}

enum ContactCategory: String, Codable, CaseIterable {
    case personal = "Personal"
    case work = "Work"
    case family = "Family"
    case friends = "Friends"
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .work: return "briefcase.fill"
        case .family: return "house.fill"
        case .friends: return "person.2.fill"
        }
    }
}

