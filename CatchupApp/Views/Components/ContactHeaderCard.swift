import SwiftUI
import SwiftData

struct ContactHeaderCard: View {
    @Bindable var contact: Contact
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    
    var categoryInfo: CategoryInfo {
        contact.categoryInfo(customCategories: customCategories)
    }
    
    var body: some View {
        // Box 1: Profile Info (Avatar + Name + Category + Birthday) - Full width
        VStack(spacing: 16) {
            ContactAvatar(contact: contact)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(contact.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                    }
                }
                
                HStack(spacing: 12) {
                    // Category
                    HStack(spacing: 4) {
                        if !categoryInfo.emoji.isEmpty {
                            Text(categoryInfo.emoji)
                                .font(.caption)
                        } else {
                            Image(systemName: categoryInfo.icon)
                                .font(.caption)
                        }
                        Text(categoryInfo.name)
                            .font(.subheadline)
                    }
                    
                    // Birthday if available
                    if let birthday = contact.birthday {
                        Text("•")
                            .font(.caption)
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption)
                            Text(birthdayString(birthday))
                                .font(.subheadline)
                        }
                    }
                }
                .foregroundColor(.secondary)
                
                // "We met..." text if available
                if !contact.weMet.isEmpty {
                    Text("We met \(contact.weMet)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func birthdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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

struct CheckInStatusView: View {
    let contact: Contact
    
    var body: some View {
        VStack(spacing: 8) {
            if contact.isOverdue {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("Waiting for you")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            } else if let nextDate = contact.nextCheckInDate {
                VStack(spacing: 4) {
                    Text("Next check-in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(nextDate.relativeTimeInMinutes())
                        .font(.headline)
                        .foregroundColor(.green)
                }
            } else {
                Text("No check-ins yet")
                    .font(.headline)
                    .foregroundColor(.orange)
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

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(height: 32)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
