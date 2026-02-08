import SwiftUI
import UIKit

struct ContactRowView: View {
    let contact: Contact

    private let categoryManager = CategoryManager.shared

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.headline)

                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                let category = categoryManager.definition(for: contact.socialCircle)
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.caption2)
                        .foregroundColor(category.color)
                    Text(category.title)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let birthday = contact.birthday {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Image(systemName: "gift.fill")
                            .font(.caption2)
                            .foregroundColor(.pink)
                        Text(birthday.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let latest = contact.latestNote, let latestTitle = latestNoteTitle(for: latest) {
                    Text(latestTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(.secondary)

                    Text(latest.createdAt.relativeTimeString())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No notes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func latestNoteTitle(for latest: ContactNote) -> String? {
        let headline = trimmed(latest.headline)
        if !headline.isEmpty { return headline }

        let summary = trimmed(latest.summary)
        if !summary.isEmpty { return summary }

        let body = latest.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return String(body.prefix(60)) }

        return nil
    }

    private func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var avatar: some View {
        Group {
            if let data = contact.profileImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                    Text(String(contact.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
