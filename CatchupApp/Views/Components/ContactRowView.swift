import SwiftUI
import SwiftData
import UIKit

extension Date {
    func relativeTimeInMinutes() -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        let minutes = Int(abs(timeInterval) / 60)
        let hours = minutes / 60
        let days = hours / 24
        
        let isFuture = timeInterval < 0
        
        if isFuture {
            // Future date
            if minutes < 1 {
                return "in a moment"
            } else if minutes < 60 {
                return "in \(minutes) min"
            } else if hours < 24 {
                return "in \(hours) hr"
            } else if days < 7 {
                return "in \(days) day\(days == 1 ? "" : "s")"
            } else {
                let weeks = days / 7
                if weeks < 4 {
                    return "in \(weeks) week\(weeks == 1 ? "" : "s")"
                } else {
                    let months = days / 30
                    if months < 12 {
                        return "in \(months) month\(months == 1 ? "" : "s")"
                    } else {
                        let years = days / 365
                        return "in \(years) year\(years == 1 ? "" : "s")"
                    }
                }
            }
        } else {
            // Past date
            if minutes < 1 {
                return "just now"
            } else if minutes < 60 {
                return "\(minutes) min ago"
            } else if hours < 24 {
                return "\(hours) hr ago"
            } else if days < 7 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else {
                let weeks = days / 7
                if weeks < 4 {
                    return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
                } else {
                    let months = days / 30
                    if months < 12 {
                        return "\(months) month\(months == 1 ? "" : "s") ago"
                    } else {
                        let years = days / 365
                        return "\(years) year\(years == 1 ? "" : "s") ago"
                    }
                }
            }
        }
    }
}

struct ContactRowView: View {
    let contact: Contact
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar
            ZStack {
                if let imageData = contact.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(contact.isOverdue ? Color.red : Color.blue, lineWidth: 2)
                        )
                } else {
                Circle()
                    .fill(contact.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(contact.name.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(contact.isOverdue ? .red : .blue)
                }
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(contact.name)
                        .font(.headline)
                    
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.leading, 4)
                    }
                    
                    Spacer()
                    
                    // Frequency aligned with chevron
                    Text("Every \(contact.frequencyDays) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status on second line
                HStack(spacing: 4) {
                    if contact.isOverdue {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Waiting for you")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    } else if let lastCheckIn = contact.lastCheckInDate {
                        Text("Last: \(lastCheckIn.relativeTimeInMinutes())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No check-ins yet")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

