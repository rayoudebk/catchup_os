import SwiftUI
import SwiftData

struct CheckInHistorySection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: Contact
    @Binding var expandedCheckInId: UUID?
    @Binding var showingCheckInSheet: Bool
    @State private var showingEditCheckIn: CheckIn? = nil
    
    var sortedCheckIns: [CheckIn] {
        contact.checkIns?.sorted(by: { $0.date > $1.date }) ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Check-ins")
                    .font(.headline)
                
                Spacer()
                
                Text("\(sortedCheckIns.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Check-in Status + Actions Section
            VStack(spacing: 16) {
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
            
            if sortedCheckIns.isEmpty {
                EmptyCheckInState()
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedCheckIns) { checkIn in
                        ExpandableCheckInRowView(
                            checkIn: checkIn,
                            isExpanded: expandedCheckInId == checkIn.id,
                            onTap: {
                                showingEditCheckIn = checkIn
                            },
                            onDelete: {
                                deleteCheckIn(checkIn)
                            }
                        )
                        
                        if checkIn.id != sortedCheckIns.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .sheet(item: $showingEditCheckIn) { checkIn in
            CheckInSheetView(contact: contact, checkIn: checkIn)
        }
    }
    
    private func deleteCheckIn(_ checkIn: CheckIn) {
        modelContext.delete(checkIn)
        
        // Update last check-in date
        if let latestCheckIn = sortedCheckIns.first(where: { $0.id != checkIn.id }) {
            contact.lastCheckInDate = latestCheckIn.date
        } else {
            contact.lastCheckInDate = nil
        }
    }
}

struct EmptyCheckInState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No check-ins yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ExpandableCheckInRowView: View {
    let checkIn: CheckIn
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            CheckInIcon()
            CheckInContent(checkIn: checkIn, isExpanded: isExpanded, onTap: onTap)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
        .padding()
    }
}

struct CheckInIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
        }
    }
}

struct CheckInContent: View {
    let checkIn: CheckIn
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(checkIn.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(checkIn.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !checkIn.note.isEmpty {
                    Text(checkIn.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .animation(.easeInOut, value: isExpanded)
                }
                
                HStack {
                    Text(checkIn.date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !checkIn.note.isEmpty && checkIn.note.count > 100 {
                        Spacer()
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

