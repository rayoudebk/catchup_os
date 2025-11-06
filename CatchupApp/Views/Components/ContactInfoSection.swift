import SwiftUI

struct ContactInfoSection: View {
    let contact: Contact
    
    var shouldShow: Bool {
        !contact.notes.isEmpty || contact.phoneNumber != nil || contact.email != nil || contact.preferredDayOfWeek != nil
    }
    
    var body: some View {
        VStack {
            if shouldShow {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact Information")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ContactDetailsRows(contact: contact)
                        PreferenceRows(contact: contact)
                        NotesSection(notes: contact.notes)
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ContactDetailsRows: View {
    let contact: Contact
    
    @ViewBuilder
    var body: some View {
        if let phoneNumber = contact.phoneNumber, !phoneNumber.isEmpty {
            InfoRow(icon: "phone.fill", title: "Phone", value: phoneNumber)
        }
        
        if let email = contact.email, !email.isEmpty {
            InfoRow(icon: "envelope.fill", title: "Email", value: email)
        }
        
        InfoRow(icon: "calendar.badge.clock", title: "Frequency", value: "Every \(contact.frequencyDays) days")
    }
}

struct PreferenceRows: View {
    let contact: Contact
    
    @ViewBuilder
    var body: some View {
        if let day = contact.preferredDayOfWeek {
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            InfoRow(icon: "calendar", title: "Preferred Day", value: dayNames[day - 1])
        }
        
        if let hour = contact.preferredHour {
            let formatter = DateFormatter()
            formatter.dateFormat = "h a"
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
            InfoRow(icon: "clock", title: "Preferred Time", value: formatter.string(from: date))
        }
    }
}

struct NotesSection: View {
    let notes: String
    
    @ViewBuilder
    var body: some View {
        if !notes.isEmpty {
            NotesRow(notes: notes)
        }
    }
}

struct NotesRow: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("Notes")
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(notes)
                .padding(.leading, 32)
        }
        .padding()
    }
}
