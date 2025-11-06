import Foundation
import SwiftData

@Model
final class Contact {
    var id: UUID
    var name: String
    var phoneNumber: String?
    var email: String?
    var categoryIdentifier: String // Stores enum rawValue for built-in, UUID string for custom
    var customCategoryId: UUID? // UUID of custom category if applicable
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
    var weMet: String // "We met..." text
    
    @Relationship(deleteRule: .cascade, inverse: \CheckIn.contact)
    var checkIns: [CheckIn]?
    
    init(
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        categoryIdentifier: String = ContactCategory.personal.rawValue,
        customCategoryId: UUID? = nil,
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
        contactIdentifier: String? = nil,
        weMet: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.categoryIdentifier = categoryIdentifier
        self.customCategoryId = customCategoryId
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
        self.weMet = weMet
        self.createdAt = Date()
        self.checkIns = []
    }
    
    // Computed property for backward compatibility - returns built-in category if it's a built-in one
    var category: ContactCategory {
        get {
            ContactCategory(rawValue: categoryIdentifier) ?? .personal
        }
        set {
            categoryIdentifier = newValue.rawValue
            customCategoryId = nil
        }
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

// Helper struct to get category display information
struct CategoryInfo {
    let name: String
    let icon: String
    let emoji: String
    let isBuiltIn: Bool
    let builtInCategory: ContactCategory?
    let customCategory: CustomCategory?
    
    static func getCategoryInfo(
        identifier: String,
        customCategoryId: UUID?,
        customCategories: [CustomCategory]
    ) -> CategoryInfo {
        // Check if it's a built-in category
        if let builtIn = ContactCategory(rawValue: identifier) {
            return CategoryInfo(
                name: builtIn.rawValue,
                icon: builtIn.icon,
                emoji: "",
                isBuiltIn: true,
                builtInCategory: builtIn,
                customCategory: nil
            )
        }
        
        // Check if it's a custom category
        if let customId = customCategoryId,
           let custom = customCategories.first(where: { $0.id == customId }) {
            return CategoryInfo(
                name: custom.name,
                icon: custom.icon,
                emoji: custom.emoji,
                isBuiltIn: false,
                builtInCategory: nil,
                customCategory: custom
            )
        }
        
        // Fallback to Personal
        return CategoryInfo(
            name: ContactCategory.personal.rawValue,
            icon: ContactCategory.personal.icon,
            emoji: "",
            isBuiltIn: true,
            builtInCategory: .personal,
            customCategory: nil
        )
    }
}

// Extension to Contact for easy category info access
extension Contact {
    func categoryInfo(customCategories: [CustomCategory]) -> CategoryInfo {
        CategoryInfo.getCategoryInfo(
            identifier: categoryIdentifier,
            customCategoryId: customCategoryId,
            customCategories: customCategories
        )
    }
}

