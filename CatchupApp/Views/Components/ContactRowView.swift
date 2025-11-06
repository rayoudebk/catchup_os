import SwiftUI
import SwiftData

struct ContactRowView: View {
    @Query(sort: \CustomCategory.order) private var customCategories: [CustomCategory]
    let contact: Contact
    
    var categoryInfo: CategoryInfo {
        contact.categoryInfo(customCategories: customCategories)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(contact.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(contact.name.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(contact.isOverdue ? .red : .blue)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.name)
                        .font(.headline)
                    
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    if !categoryInfo.emoji.isEmpty {
                        Text(categoryInfo.emoji)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: categoryInfo.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(categoryInfo.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text("Every \(contact.frequencyDays) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status
                HStack(spacing: 4) {
                    if contact.isOverdue {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Overdue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    } else if let lastCheckIn = contact.lastCheckInDate {
                        Text("Last: \(lastCheckIn, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if contact.daysUntilNextCheckIn > 0 {
                            Text("· \(contact.daysUntilNextCheckIn)d left")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("No check-ins yet")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

