import SwiftUI

struct PhotoMemoriesSection: View {
    @Bindable var contact: Contact
    @Binding var showingPhotosLinkSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photo Memories 📸")
                    .font(.headline)
                Spacer()
                Button {
                    showingPhotosLinkSheet = true
                } label: {
                    Image(systemName: contact.photosPersonLocalIdentifier == nil ? "link" : "link.badge.plus")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if let personId = contact.photosPersonLocalIdentifier, !personId.isEmpty {
                PhotoCarouselView(personIdentifier: personId)
            } else {
                EmptyPhotoState(showingPhotosLinkSheet: $showingPhotosLinkSheet)
            }
        }
    }
}

struct EmptyPhotoState: View {
    @Binding var showingPhotosLinkSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No photos recorded")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Take a photo together next time!")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                showingPhotosLinkSheet = true
            } label: {
                Text("Link Photos Album")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

