import SwiftUI

struct RemindersSection: View {
    @Bindable var contact: Contact
    @Binding var showingAddReminder: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddReminder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if contact.reminders.isEmpty {
                Text("No reminders yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(contact.reminders.enumerated()), id: \.offset) { index, reminder in
                        ReminderRow(
                            reminder: reminder,
                            index: index,
                            isLast: index == contact.reminders.count - 1,
                            onToggle: { toggleReminder(at: index) },
                            onDelete: { deleteReminder(at: index) }
                        )
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private func toggleReminder(at index: Int) {
        if contact.reminders[index].hasPrefix("✓ ") {
            contact.reminders[index] = String(contact.reminders[index].dropFirst(2))
        } else {
            contact.reminders[index] = "✓ " + contact.reminders[index]
        }
    }
    
    private func deleteReminder(at index: Int) {
        contact.reminders.remove(at: index)
    }
}

struct ReminderRow: View {
    let reminder: String
    let index: Int
    let isLast: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: reminder.hasPrefix("✓ ") ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.hasPrefix("✓ ") ? .green : .gray)
                }
                
                Text(reminder.hasPrefix("✓ ") ? String(reminder.dropFirst(2)) : reminder)
                    .strikethrough(reminder.hasPrefix("✓ "))
                    .foregroundColor(reminder.hasPrefix("✓ ") ? .secondary : .primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            if !isLast {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

