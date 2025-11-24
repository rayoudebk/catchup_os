import SwiftUI

struct StatsHeaderView: View {
    let overdueCount: Int
    let recentCatchupsCount: Int
    @Binding var showingOverdueOnly: Bool
    @Binding var showingRecentCatchupsOnly: Bool
    var onOverdueToggle: (() -> Void)? = nil
    var onRecentCatchupsToggle: (() -> Void)? = nil
    var onRecordCheckIn: (() -> Void)? = nil
    
    @State private var leftColumnHeight: CGFloat = 0
    
    let goalCatchups = 5
    
    // Emoji based on catchup count (0 = sad, 5 = happy)
    var catchupEmoji: String {
        switch recentCatchupsCount {
        case 0: return "😢"
        case 1: return "😕"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        default: return "😄" // 5 or more
        }
    }
    
    var progress: Double {
        min(Double(recentCatchupsCount) / Double(goalCatchups), 1.0)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side: Two stacked cards - determines the height
            VStack(alignment: .leading, spacing: 12) {
                // Top left card: Catch ups progress
                Button {
                    showingRecentCatchupsOnly.toggle()
                    onRecentCatchupsToggle?()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        Text("Catch ups this week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Progress bar, emoji, and count in a single HStack row
                        HStack(spacing: 8) {
                            // Segmented progress bar with fixed width
                            HStack(spacing: 4) {
                                ForEach(0..<goalCatchups, id: \.self) { index in
                                    Capsule()
                                        .fill(index < recentCatchupsCount ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .frame(width: 12, height: 3)
                                }
                            }
                            .frame(width: 80)
                            
                            // Emoji
                            Text(catchupEmoji)
                                .font(.system(size: 14))
                            
                            // Count
                            Text("\(recentCatchupsCount)/\(goalCatchups)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(showingRecentCatchupsOnly ? Color.blue.opacity(0.2) : Color.blue.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(showingRecentCatchupsOnly ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Bottom left card: Waiting for you (always shown)
                Button {
                    showingOverdueOnly.toggle()
                    onOverdueToggle?()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(overdueCount) connections waiting for you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(showingOverdueOnly ? Color(UIColor.secondarySystemBackground).opacity(0.8) : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(showingOverdueOnly ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(key: VStackHeightPreferenceKey.self, value: geometry.size.height)
                }
            )
            
            // Right card: Record check-in - shorter height
            Button {
                onRecordCheckIn?()
            } label: {
                VStack(spacing: 4) {
                    Text("Record")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("check-in")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color.blue)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clear, lineWidth: 2)
                )
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(height: leftColumnHeight > 0 ? leftColumnHeight * 0.7 : nil)
        }
        .onPreferenceChange(VStackHeightPreferenceKey.self) { height in
            leftColumnHeight = height
        }
    }
}

// Preference key to track VStack height
struct VStackHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

