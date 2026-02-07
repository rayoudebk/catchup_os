import Foundation
import SwiftUI

struct SocialCircleDefinition: Identifiable {
    let circle: SocialCircle
    let title: String
    let icon: String
    let color: Color
    let order: Int

    var id: SocialCircle { circle }
}

final class CategoryManager {
    static let shared = CategoryManager()

    private init() {}

    private let definitions: [SocialCircleDefinition] = [
        SocialCircleDefinition(circle: .personal, title: "Personal", icon: "person.crop.circle", color: .blue, order: 0),
        SocialCircleDefinition(circle: .family, title: "Family", icon: "house", color: .pink, order: 1),
        SocialCircleDefinition(circle: .friends, title: "Friends", icon: "person.3", color: .green, order: 2),
        SocialCircleDefinition(circle: .work, title: "Work", icon: "briefcase", color: .orange, order: 3),
        SocialCircleDefinition(circle: .other, title: "Other", icon: "square.grid.2x2", color: .gray, order: 4)
    ]

    var all: [SocialCircleDefinition] {
        definitions.sorted { $0.order < $1.order }
    }

    func definition(for circle: SocialCircle) -> SocialCircleDefinition {
        all.first(where: { $0.circle == circle }) ?? SocialCircleDefinition(
            circle: .other,
            title: "Other",
            icon: "square.grid.2x2",
            color: .gray,
            order: 4
        )
    }
}
