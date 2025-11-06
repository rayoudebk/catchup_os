import Foundation
import Combine
import SwiftUI

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    private let disabledCategoriesKey = "disabledCategories"
    private let builtInCategoryOrderKey = "builtInCategoryOrder" // Dictionary: category name -> order
    
    private init() {}
    
    @Published var refreshTrigger = UUID()
    
    var disabledCategories: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: disabledCategoriesKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: disabledCategoriesKey)
            refreshTrigger = UUID()
        }
    }
    
    // Store order for built-in categories as dictionary: category name -> order integer
    var builtInCategoryOrder: [String: Int] {
        get {
            if let data = UserDefaults.standard.data(forKey: builtInCategoryOrderKey),
               let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
                return dict
            }
            // Default order: assign sequential values starting from 0
            var defaultOrder: [String: Int] = [:]
            for (index, category) in ContactCategory.allCases.enumerated() {
                defaultOrder[category.rawValue] = index
            }
            return defaultOrder
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: builtInCategoryOrderKey)
                refreshTrigger = UUID()
            }
        }
    }
    
    // Get order for a built-in category
    func getOrder(for category: ContactCategory) -> Int {
        return builtInCategoryOrder[category.rawValue] ?? Int.max
    }
    
    // Set order for a built-in category
    func setOrder(_ order: Int, for category: ContactCategory) {
        var orderDict = builtInCategoryOrder
        orderDict[category.rawValue] = order
        builtInCategoryOrder = orderDict
    }
    
    var enabledCategories: [ContactCategory] {
        let enabled = ContactCategory.allCases.filter { !disabledCategories.contains($0.rawValue) }
        
        // Sort by order value
        return enabled.sorted { cat1, cat2 in
            let order1 = getOrder(for: cat1)
            let order2 = getOrder(for: cat2)
            return order1 < order2
        }
    }
    
    func disableCategory(_ category: ContactCategory) {
        guard category != .personal else { return } // Can't disable Personal
        var disabled = disabledCategories
        disabled.insert(category.rawValue)
        disabledCategories = disabled
    }
    
    func enableCategory(_ category: ContactCategory) {
        var disabled = disabledCategories
        disabled.remove(category.rawValue)
        disabledCategories = disabled
    }
    
    func isEnabled(_ category: ContactCategory) -> Bool {
        !disabledCategories.contains(category.rawValue)
    }
}
