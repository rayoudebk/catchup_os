import Foundation
import SwiftData

@Model
final class CustomCategory {
    var id: UUID
    var name: String
    var emoji: String
    var icon: String // SF Symbol name
    var order: Int // For sorting
    var createdAt: Date
    
    init(name: String, emoji: String, icon: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.icon = icon
        self.order = order
        self.createdAt = Date()
    }
}

