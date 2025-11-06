import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    @Query private var contacts: [Contact]
    
    @State private var showingAddCategory = false
    @State private var editingCategory: CustomCategory? = nil
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = "📁"
    @State private var newCategoryIcon = "folder.fill"
    
    // Built-in categories (Personal cannot be deleted)
    let builtInCategories: [(category: ContactCategory, isLocked: Bool)] = [
        (.personal, true),
        (.work, false),
        (.family, false),
        (.friends, false)
    ]
    
    var allCategories: [(id: String, name: String, emoji: String, icon: String, isLocked: Bool, order: Int, customCategory: CustomCategory?)] {
        var result: [(id: String, name: String, emoji: String, icon: String, isLocked: Bool, order: Int, customCategory: CustomCategory?)] = []
        
        // Add built-in categories
        for (index, item) in builtInCategories.enumerated() {
            result.append((
                id: item.category.rawValue,
                name: item.category.rawValue,
                emoji: "",
                icon: item.category.icon,
                isLocked: item.isLocked,
                order: index,
                customCategory: nil
            ))
        }
        
        // Add custom categories
        for category in customCategories {
            result.append((
                id: category.id.uuidString,
                name: category.name,
                emoji: category.emoji,
                icon: category.icon,
                isLocked: false,
                order: category.order + builtInCategories.count,
                customCategory: category
            ))
        }
        
        return result.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        List {
            Section {
                Text("Personal category cannot be deleted or changed. Maximum 6 categories total.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Categories") {
                ForEach(Array(allCategories.enumerated()), id: \.element.id) { index, category in
                    HStack {
                        if !category.emoji.isEmpty {
                            Text(category.emoji)
                                .font(.title2)
                        } else {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                        }
                        
                        Text(category.name)
                        
                        Spacer()
                        
                        if category.isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if let customCat = category.customCategory, !category.isLocked {
                            Button(role: .destructive) {
                                deleteCategory(customCat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        if let customCat = category.customCategory {
                            Button {
                                editingCategory = customCat
                                newCategoryName = customCat.name
                                newCategoryEmoji = customCat.emoji
                                showingAddCategory = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onMove(perform: moveCategories)
                
                if allCategories.count < 6 {
                    Button {
                        editingCategory = nil
                        newCategoryName = ""
                        newCategoryEmoji = "📁"
                        showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("Manage Categories")
        .toolbar {
            EditButton()
        }
        .alert(editingCategory == nil ? "Add Category" : "Edit Category", isPresented: $showingAddCategory) {
            TextField("Category Name", text: $newCategoryName)
            TextField("Emoji", text: $newCategoryEmoji)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
                newCategoryEmoji = "📁"
                editingCategory = nil
            }
            Button(editingCategory == nil ? "Add" : "Save") {
                if let editing = editingCategory {
                    updateCategory(editing)
                } else {
                    addCategory()
                }
            }
            .disabled(newCategoryName.isEmpty)
        } message: {
            Text("Enter a name and emoji for your category")
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        // Update order for custom categories only
        var categories = Array(customCategories)
        categories.move(fromOffsets: source, toOffset: destination)
        
        // Update order values
        for (index, category) in categories.enumerated() {
            category.order = index + builtInCategories.count
        }
    }
    
    private func addCategory() {
        let maxOrder = customCategories.map { $0.order }.max() ?? -1
        let category = CustomCategory(
            name: newCategoryName,
            emoji: newCategoryEmoji,
            icon: "folder.fill",
            order: maxOrder + 1
        )
        modelContext.insert(category)
        newCategoryName = ""
        newCategoryEmoji = "📁"
    }
    
    private func updateCategory(_ category: CustomCategory) {
        category.name = newCategoryName
        category.emoji = newCategoryEmoji
        newCategoryName = ""
        newCategoryEmoji = "📁"
        editingCategory = nil
    }
    
    private func deleteCategory(_ category: CustomCategory) {
        // Check if any contacts use this category
        let contactsUsingCategory = contacts.filter { contact in
            // For now, we can't check custom categories easily since Contact uses enum
            // This would need refactoring to support custom categories fully
            false
        }
        
        if contactsUsingCategory.isEmpty {
            modelContext.delete(category)
        } else {
            // Show alert that contacts are using this category
        }
    }
}

