import Foundation
import Contacts

/// Represents a contact that can be blocked or is an emergency contact
struct BlockedContact: Codable, Identifiable, Hashable {
    let id: String  // CNContact identifier
    
    /// Contact's full name
    let fullName: String
    
    /// Contact's phone number (primary)
    let phoneNumber: String?
    
    /// Category for organization
    var category: ContactCategory
    
    /// Whether this contact is blocked during protection
    var isBlocked: Bool
    
    /// Whether this contact is an emergency contact (always accessible)
    var isEmergencyContact: Bool
    
    init(
        id: String,
        fullName: String,
        phoneNumber: String? = nil,
        category: ContactCategory = .other,
        isBlocked: Bool = false,
        isEmergencyContact: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.category = category
        self.isBlocked = isBlocked
        self.isEmergencyContact = isEmergencyContact
    }
    
    /// Create from a CNContact
    init(from contact: CNContact, category: ContactCategory = .other) {
        self.id = contact.identifier
        self.fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
        self.phoneNumber = contact.phoneNumbers.first?.value.stringValue
        self.category = category
        self.isBlocked = false
        self.isEmergencyContact = false
    }
}

/// Categories for organizing blocked contacts
enum ContactCategory: String, Codable, CaseIterable {
    case ex         // Ex-partner
    case boss       // Work supervisor
    case family     // Family member
    case friend     // Friend
    case coworker   // Work colleague
    case other      // Other
    
    var displayName: String {
        switch self {
        case .ex: return "Ex"
        case .boss: return "Boss"
        case .family: return "Family"
        case .friend: return "Friend"
        case .coworker: return "Coworker"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .ex: return "heart.slash"
        case .boss: return "briefcase"
        case .family: return "house"
        case .friend: return "person.2"
        case .coworker: return "building.2"
        case .other: return "person"
        }
    }
    
    var color: String {
        switch self {
        case .ex: return "red"
        case .boss: return "purple"
        case .family: return "blue"
        case .friend: return "green"
        case .coworker: return "orange"
        case .other: return "gray"
        }
    }
}
