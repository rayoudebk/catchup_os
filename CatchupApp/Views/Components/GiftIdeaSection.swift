import SwiftUI

struct GiftIdeaSection: View {
    @Bindable var contact: Contact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next Gift Idea 🎁")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            TextField("What would they love?", text: $contact.giftIdea, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }
}

