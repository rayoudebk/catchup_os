import SwiftUI

struct ContactHeaderCard: View {
    @Bindable var contact: Contact
    @Binding var showingCheckInSheet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ContactAvatar(contact: contact)
            ContactNameSection(contact: contact)
            CheckInStatusView(contact: contact)
            QuickActionsView(contact: contact)
            
            Button {
                showingCheckInSheet = true
            } label: {
                Label("Record Check-in", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ContactAvatar: View {
    let contact: Contact
    
    var body: some View {
        ZStack {
            if let imageData = contact.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(contact.isOverdue ? Color.red : Color.blue, lineWidth: 2)
                    )
            } else {
                Circle()
                    .fill(contact.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text(contact.name.prefix(1).uppercased())
                    .font(.system(size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(contact.isOverdue ? .red : .blue)
            }
        }
    }
}

struct ContactNameSection: View {
    let contact: Contact
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(contact.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if contact.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: contact.category.icon)
                    .font(.caption)
                Text(contact.category.rawValue)
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)
            
            if let birthday = contact.birthday {
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.caption2)
                    Text(birthdayString(birthday))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func birthdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct CheckInStatusView: View {
    let contact: Contact
    
    var body: some View {
        VStack(spacing: 8) {
            if contact.isOverdue {
                Label("Overdue - Time to reach out!", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
            } else if let nextDate = contact.nextCheckInDate {
                VStack(spacing: 4) {
                    Text("Next check-in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(nextDate, style: .relative)
                        .font(.headline)
                        .foregroundColor(.green)
                }
            } else {
                Text("No check-ins yet")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            if let lastCheckIn = contact.lastCheckInDate {
                Text("Last check-in: \(lastCheckIn, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct QuickActionsView: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            if let phoneNumber = contact.phoneNumber, !phoneNumber.isEmpty {
                QuickActionButton(
                    icon: "phone.fill",
                    title: "Call",
                    color: .green
                ) {
                    openWhatsAppCall(phoneNumber: phoneNumber)
                }
            }
            
            if let phoneNumber = contact.phoneNumber, !phoneNumber.isEmpty {
                QuickActionButton(
                    icon: "message.fill",
                    title: "Chat",
                    color: .blue
                ) {
                    openWhatsAppChat(phoneNumber: phoneNumber)
                }
            }
            
            QuickActionButton(
                icon: "fork.knife",
                title: "Meet Up",
                color: .orange
            ) {
                openRestaurantsNearby()
            }
        }
    }
    
    private func openWhatsAppCall(phoneNumber: String) {
        let cleanNumber = phoneNumber.filter { $0.isNumber }
        if let url = URL(string: "https://wa.me/\(cleanNumber)?call=1") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWhatsAppChat(phoneNumber: String) {
        let cleanNumber = phoneNumber.filter { $0.isNumber }
        if let url = URL(string: "https://wa.me/\(cleanNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openRestaurantsNearby() {
        if let url = URL(string: "https://www.google.com/maps/search/restaurants+near+me") {
            UIApplication.shared.open(url)
        }
    }
}

