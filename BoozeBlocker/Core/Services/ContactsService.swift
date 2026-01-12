import Foundation
import Contacts

/// Service for accessing and managing contacts
class ContactsService: ObservableObject {
    static let shared = ContactsService()
    
    @Published private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published private(set) var contacts: [BlockedContact] = []
    
    private let store = CNContactStore()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return granted
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }
    
    // MARK: - Fetching Contacts
    
    func fetchAllContacts() async -> [BlockedContact] {
        guard authorizationStatus == .authorized else {
            return []
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
        
        var fetchedContacts: [BlockedContact] = []
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .userDefault
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let blockedContact = BlockedContact(from: contact)
                fetchedContacts.append(blockedContact)
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }
        
        await MainActor.run {
            self.contacts = fetchedContacts
        }
        
        return fetchedContacts
    }
    
    /// Search contacts by name
    func searchContacts(query: String) -> [BlockedContact] {
        guard !query.isEmpty else { return contacts }
        
        let lowercasedQuery = query.lowercased()
        return contacts.filter { contact in
            contact.fullName.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Get a specific contact by ID
    func getContact(identifier: String) -> BlockedContact? {
        return contacts.first { $0.id == identifier }
    }
    
    /// Fetch a single contact from the store
    func fetchContact(identifier: String) async -> BlockedContact? {
        guard authorizationStatus == .authorized else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
        
        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
            return BlockedContact(from: contact)
        } catch {
            print("Error fetching contact: \(error)")
            return nil
        }
    }
}
