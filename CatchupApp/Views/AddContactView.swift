import SwiftUI
import SwiftData
import Contacts
import ContactsUI

struct AddContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingContactsPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Add Contacts")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select contacts from your phone to start tracking check-ins")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    showingContactsPicker = true
                } label: {
                    Label("Select from Contacts", systemImage: "person.2.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Add Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingContactsPicker) {
                ContactPickerView { cnContacts in
                    importContacts(cnContacts)
                }
            }
        }
    }
    
    private func importContacts(_ cnContacts: [CNContact]) {
        for cnContact in cnContacts {
            // Extract contact info
            let name = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumber = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value as String?
            let birthday = cnContact.birthday?.date
            
            // Get profile image
            let imageData: Data? = cnContact.imageData ?? cnContact.thumbnailImageData
            
            // Create contact with defaults: Personal category, Monthly frequency
            let contact = Contact(
                name: name.isEmpty ? "Unknown" : name,
                phoneNumber: phoneNumber,
                email: email,
                categoryIdentifier: ContactCategory.personal.rawValue,
                customCategoryId: nil,
                frequencyDays: 30, // Default to Monthly
                photosPersonLocalIdentifier: nil,
                birthday: birthday,
                profileImageData: imageData,
                contactIdentifier: cnContact.identifier
            )
            
            modelContext.insert(contact)
        }
        
        dismiss()
    }
}

// ContactPicker wrapper for UIKit CNContactPickerViewController
struct ContactPickerView: UIViewControllerRepresentable {
    let onSelect: ([CNContact]) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        
        // Configure what properties to fetch
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactBirthdayKey,
            CNContactImageDataKey,
            CNContactThumbnailImageDataKey
        ]
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelect(contacts)
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // User cancelled
        }
    }
}

// Extension to convert CNBirthday to Date
extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}
