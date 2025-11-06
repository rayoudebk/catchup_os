import SwiftUI
import SwiftData

struct CheckInSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let contact: Contact
    
    @State private var title = "Check-in"
    @State private var note = ""
    @State private var checkInDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Check-in title", text: $title)
                        .placeholder(when: title.isEmpty) {
                            Text("e.g., Coffee chat, Phone call, Lunch")
                                .foregroundColor(.secondary)
                        }
                }
                
                Section("Date & Time") {
                    DatePicker("Check-in Date", selection: $checkInDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextEditor(text: $note)
                        .frame(height: 120)
                    
                    Text("Add details about your conversation or interaction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You'll be reminded to check in again in:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(contact.frequencyDays) days")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Record Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCheckIn()
                    }
                }
            }
        }
    }
    
    private func saveCheckIn() {
        let checkIn = CheckIn(
            date: checkInDate,
            note: note,
            title: title.isEmpty ? "Check-in" : title,
            contact: contact
        )
        
        modelContext.insert(checkIn)
        
        // Update contact's last check-in date
        contact.lastCheckInDate = checkInDate
        
        // Reschedule notification
        NotificationManager.shared.scheduleNotification(for: contact)
        
        dismiss()
    }
}

// Helper extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

