import SwiftUI

struct StatsHeaderView: View {
    let overdueCount: Int
    let recentCatchupsCount: Int
    @Binding var showingOverdueOnly: Bool
    @Binding var showingRecentCatchupsOnly: Bool
    var onOverdueToggle: (() -> Void)? = nil
    var onRecentCatchupsToggle: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 20) {
            Button {
                showingRecentCatchupsOnly.toggle()
                onRecentCatchupsToggle?()
            } label: {
                StatCard(
                    title: "Catch ups (last 7 days)",
                    value: "\(recentCatchupsCount)",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    isSelected: showingRecentCatchupsOnly
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button {
                showingOverdueOnly.toggle()
                onOverdueToggle?()
            } label: {
                StatCard(
                    title: "Catchup Overdue",
                    value: "\(overdueCount)",
                    icon: "exclamationmark.circle.fill",
                    color: overdueCount > 0 ? .red : .green,
                    isSelected: showingOverdueOnly
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    
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
        .background(isSelected ? color.opacity(0.1) : Color(UIColor.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

