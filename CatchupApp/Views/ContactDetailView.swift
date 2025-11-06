import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: Contact
    
    @State private var showingCheckInSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAddReminder = false
    @State private var newReminderText = ""
    @State private var expandedCheckInId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ContactHeaderCard(contact: contact)
                RemindersSection(contact: contact, showingAddReminder: $showingAddReminder)
                CheckInHistorySection(contact: contact, expandedCheckInId: $expandedCheckInId, showingCheckInSheet: $showingCheckInSheet)
                GiftIdeaSection(contact: contact)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Contact", systemImage: "pencil")
                    }
                    
                    Button {
                        contact.isFavorite.toggle()
                    } label: {
                        Label(
                            contact.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: contact.isFavorite ? "star.slash" : "star"
                        )
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Contact", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingCheckInSheet) {
            CheckInSheetView(contact: contact)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: contact)
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteContact()
            }
        } message: {
            Text("Are you sure you want to delete \(contact.name)? This will also delete all check-in history.")
        }
        .alert("Add Reminder", isPresented: $showingAddReminder) {
            TextField("Reminder", text: $newReminderText)
            Button("Cancel", role: .cancel) {
                newReminderText = ""
            }
            Button("Add") {
                if !newReminderText.isEmpty {
                    contact.reminders.append(newReminderText)
                    newReminderText = ""
                }
            }
        }
    }
    
    private func deleteContact() {
        modelContext.delete(contact)
    }
}

// Helper views used by components
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
        .padding()
    }
}
