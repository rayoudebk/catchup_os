import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), overdueContacts: [], upcomingContacts: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), overdueContacts: [], upcomingContacts: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entry = await fetchContactsData()
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchContactsData() async -> SimpleEntry {
        // In a real app, you'd fetch from the shared SwiftData container
        // For now, return mock data
        return SimpleEntry(date: Date(), overdueContacts: [], upcomingContacts: [])
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let overdueContacts: [ContactSnapshot]
    let upcomingContacts: [ContactSnapshot]
}

struct ContactSnapshot: Identifiable {
    let id: UUID
    let name: String
    let daysUntilCheckIn: Int
    let isOverdue: Bool
}

struct CatchupWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title3)
                Spacer()
                Text("Catchup")
                    .font(.headline)
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            if entry.overdueContacts.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All caught up!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            } else {
                VStack(spacing: 4) {
                    Text("\(entry.overdueContacts.count)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    Text("need attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Catchup", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            if entry.overdueContacts.isEmpty && entry.upcomingContacts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All caught up!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("No contacts need attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 16) {
                    // Overdue
                    VStack(spacing: 8) {
                        Text("\(entry.overdueContacts.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.red)
                        Text("Overdue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Upcoming
                    VStack(spacing: 8) {
                        Text("\(entry.upcomingContacts.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.orange)
                        Text("This Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
    }
}

struct LargeWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Catchup", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            if entry.overdueContacts.isEmpty && entry.upcomingContacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("All caught up!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("You're doing great at staying connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !entry.overdueContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Overdue (\(entry.overdueContacts.count))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(entry.overdueContacts.prefix(3)) { contact in
                                HStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                    Text(contact.name)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if !entry.upcomingContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text("Coming Up (\(entry.upcomingContacts.count))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(entry.upcomingContacts.prefix(3)) { contact in
                                HStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                    Text(contact.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(contact.daysUntilCheckIn)d")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
}

struct CatchupWidget: Widget {
    let kind: String = "CatchupWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CatchupWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Catchup")
        .description("Keep track of who you need to catch up with")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    CatchupWidget()
} timeline: {
    SimpleEntry(date: .now, overdueContacts: [], upcomingContacts: [])
}

