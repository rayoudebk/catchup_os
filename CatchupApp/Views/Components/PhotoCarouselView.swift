import SwiftUI
import Photos

struct PhotoCarouselView: View {
    let personIdentifier: String
    
    @State private var photos: [PHAsset] = []
    @State private var loadedImages: [String: UIImage] = [:]
    @StateObject private var photosManager = PhotosManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if photos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                        Text("No photos found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 150, height: 150)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(12)
                } else {
                    ForEach(photos, id: \.localIdentifier) { asset in
                        if let image = loadedImages[asset.localIdentifier] {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .frame(width: 150, height: 150)
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 170)
        .onAppear {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        photos = photosManager.fetchPhotosForPerson(localIdentifier: personIdentifier, limit: 10)
        
        // Load images
        for asset in photos {
            photosManager.loadImage(from: asset, targetSize: CGSize(width: 300, height: 300)) { image in
                if let image = image {
                    loadedImages[asset.localIdentifier] = image
                }
            }
        }
    }
}

struct LinkPhotosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: Contact
    
    @State private var collections: [(name: String, identifier: String, count: Int)] = []
    @State private var selectedIdentifier: String?
    @StateObject private var photosManager = PhotosManager.shared
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                if photosManager.authorizationStatus == .authorized || photosManager.authorizationStatus == .limited {
                    List {
                        Section {
                            Text("Select a photo album that contains memories with \(contact.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Section("Albums") {
                            if collections.isEmpty {
                                Text("No albums found")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(collections, id: \.identifier) { collection in
                                    Button {
                                        selectedIdentifier = collection.identifier
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(collection.name)
                                                    .foregroundColor(.primary)
                                                Text("\(collection.count) photos")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedIdentifier == collection.identifier || contact.photosPersonLocalIdentifier == collection.identifier {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Photos Access Required")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("To link photo memories with contacts, we need access to your Photos library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            requestPhotosAccess()
                        } label: {
                            Text("Grant Access")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal, 40)
                        }
                    }
                }
            }
            .navigationTitle("Link Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if photosManager.authorizationStatus == .authorized || photosManager.authorizationStatus == .limited {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let identifier = selectedIdentifier {
                                contact.photosPersonLocalIdentifier = identifier
                            }
                            dismiss()
                        }
                        .disabled(selectedIdentifier == nil && contact.photosPersonLocalIdentifier == nil)
                    }
                }
            }
            .onAppear {
                if photosManager.authorizationStatus == .authorized || photosManager.authorizationStatus == .limited {
                    loadCollections()
                }
            }
            .alert("Photos Access", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Photos access in Settings to use this feature")
            }
        }
    }
    
    private func requestPhotosAccess() {
        photosManager.requestAuthorization { granted in
            if granted {
                loadCollections()
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    private func loadCollections() {
        collections = photosManager.fetchAllPeopleCollections()
        selectedIdentifier = contact.photosPersonLocalIdentifier
    }
}

