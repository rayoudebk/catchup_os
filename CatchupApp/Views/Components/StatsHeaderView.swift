import SwiftUI

struct StatsHeaderView: View {
    let totalContacts: Int
    let overdueCount: Int
    
    var body: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Total Contacts",
                value: "\(totalContacts)",
                icon: "person.2.fill",
                color: .blue
            )
            
            StatCard(
                title: "Need Attention",
                value: "\(overdueCount)",
                icon: "exclamationmark.circle.fill",
                color: overdueCount > 0 ? .red : .green
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

