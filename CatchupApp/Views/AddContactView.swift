import SwiftUI
import SwiftData

struct AddContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var category: ContactCategory = .personal
    @State private var frequencyDays = 14
    @State private var preferredDayOfWeek: Int? = nil
    @State private var preferredHour: Int? = 9
    @State private var notes = ""
    @State private var isFavorite = false
    
    let frequencyOptions = [7, 14, 21, 30, 60, 90, 180, 365]
    let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ContactCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(.blue)
                        Text(category.rawValue)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                Section("Check-in Frequency") {
                    Picker("Check in every", selection: $frequencyDays) {
                        ForEach(frequencyOptions, id: \.self) { days in
                            Text("\(frequencyLabel(for: days))")
                                .tag(days)
                        }
                    }
                    
                    Picker("Preferred Day", selection: $preferredDayOfWeek) {
                        Text("Any Day").tag(nil as Int?)
                        ForEach(0..<7) { index in
                            Text(daysOfWeek[index]).tag(index + 1 as Int?)
                        }
                    }
                    
                    Picker("Preferred Time", selection: $preferredHour) {
                        Text("Any Time").tag(nil as Int?)
                        ForEach(0..<24) { hour in
                            Text(formatHour(hour)).tag(hour as Int?)
                        }
                    }
                    
                    Text(buildReminderText())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addContact()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func addContact() {
        let contact = Contact(
            name: name.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            email: email.isEmpty ? nil : email,
            category: category,
            frequencyDays: frequencyDays,
            preferredDayOfWeek: preferredDayOfWeek,
            preferredHour: preferredHour,
            notes: notes,
            isFavorite: isFavorite
        )
        
        modelContext.insert(contact)
        
        // Schedule notification
        NotificationManager.shared.scheduleNotification(for: contact)
        
        dismiss()
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
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
    
    private func buildReminderText() -> String {
        var text = "You'll be reminded to reach out every \(frequencyLabel(for: frequencyDays).lowercased())"
        if let day = preferredDayOfWeek {
            text += " on \(daysOfWeek[day - 1])s"
        }
        if let hour = preferredHour {
            text += " at \(formatHour(hour))"
        }
        return text
    }
}

