import SwiftUI

struct PhotosTogetherSection: View {
    @Bindable var contact: Contact
    @State private var showingPhotosLinkSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos Together")
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
        .sheet(isPresented: $showingPhotosLinkSheet) {
            LinkPhotosSheet(contact: contact)
        }
    }
}

struct EmptyPhotoState: View {
    @Binding var showingPhotosLinkSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No photos yet")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Photos will automatically link if found in your Photos app")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
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

