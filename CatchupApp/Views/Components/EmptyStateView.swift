import SwiftUI

struct EmptyStateView: View {
    let hasContacts: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasContacts ? "magnifyingglass" : "person.crop.circle.badge.plus")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text(hasContacts ? "No matching contacts" : "No contacts yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text(hasContacts ? "Try a different search term." : "Add people from your address book to start keeping notes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
