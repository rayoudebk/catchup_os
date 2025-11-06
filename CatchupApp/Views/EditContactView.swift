import SwiftUI

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: Contact
    
    let frequencyOptions = [7, 14, 21, 30, 60, 90, 180, 365]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $contact.name)
                    
                    TextField("Phone Number", text: Binding(
                        get: { contact.phoneNumber ?? "" },
                        set: { contact.phoneNumber = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                    
                    TextField("Email", text: Binding(
                        get: { contact.email ?? "" },
                        set: { contact.email = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                }
                
                Section("Category") {
                    Picker("Category", selection: $contact.category) {
                        ForEach(ContactCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Image(systemName: contact.category.icon)
                            .foregroundColor(.blue)
                        Text(contact.category.rawValue)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                Section("Check-in Frequency") {
                    Picker("Check in every", selection: $contact.frequencyDays) {
                        ForEach(frequencyOptions, id: \.self) { days in
                            Text("\(frequencyLabel(for: days))")
                                .tag(days)
                        }
                    }
                    
                    Text("You'll be reminded to reach out every \(frequencyLabel(for: contact.frequencyDays).lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Notes") {
                    TextEditor(text: $contact.notes)
                        .frame(height: 100)
                }
                
                Section {
                    Toggle(isOn: $contact.isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Reschedule notification with new frequency
                        NotificationManager.shared.scheduleNotification(for: contact)
                        dismiss()
                    }
                    .disabled(contact.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func frequencyLabel(for days: Int) -> String {
        switch days {
        case 7: return "Week"
        case 14: return "2 Weeks"
        case 21: return "3 Weeks"
        case 30: return "Month"
        case 60: return "2 Months"
        case 90: return "3 Months"
        case 180: return "6 Months"
        case 365: return "Year"
        default: return "\(days) Days"
        }
    }
}

