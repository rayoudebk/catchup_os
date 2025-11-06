import Foundation
import Combine
import SwiftUI

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    private let disabledCategoriesKey = "disabledCategories"
    private let categoryOrderKey = "categoryOrder"
    
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
    
    var categoryOrder: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: categoryOrderKey) ?? ContactCategory.allCases.map { $0.rawValue }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: categoryOrderKey)
            refreshTrigger = UUID()
        }
    }
    
    var enabledCategories: [ContactCategory] {
        let enabled = ContactCategory.allCases.filter { !disabledCategories.contains($0.rawValue) }
        
        // Sort by custom order if available
        let order = categoryOrder
        return enabled.sorted { cat1, cat2 in
            let index1 = order.firstIndex(of: cat1.rawValue) ?? Int.max
            let index2 = order.firstIndex(of: cat2.rawValue) ?? Int.max
            return index1 < index2
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
    
    func reorderCategories(from source: IndexSet, to destination: Int) {
        var ordered = enabledCategories.map { $0.rawValue }
        ordered.move(fromOffsets: source, toOffset: destination)
        
        // Update order for all categories (including disabled ones)
        var allOrdered = categoryOrder
        let enabledSet = Set(enabledCategories.map { $0.rawValue })
        
        // Remove enabled categories from current order
        allOrdered.removeAll { enabledSet.contains($0) }
        
        // Insert enabled categories at the new position
        let insertIndex = min(destination, allOrdered.count)
        allOrdered.insert(contentsOf: ordered, at: insertIndex)
        
        categoryOrder = allOrdered
    }
}

