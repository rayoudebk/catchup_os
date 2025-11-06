import SwiftUI

struct EmptyStateView: View {
    let hasContacts: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasContacts ? "magnifyingglass" : "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(hasContacts ? "No contacts found" : "No contacts yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(hasContacts ? "Try adjusting your search or filters" : "Add your first contact to start building meaningful connections")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

