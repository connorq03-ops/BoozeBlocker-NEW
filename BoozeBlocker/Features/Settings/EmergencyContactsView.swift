import SwiftUI

struct EmergencyContactsView: View {
    @StateObject private var contactsService = ContactsService.shared
    @State private var emergencyContacts: [BlockedContact] = []
    @State private var showAddContact = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        List {
            // Info Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "staroflife.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Always Accessible")
                            .fontWeight(.semibold)
                        Text("These contacts can always be reached, even when protection is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Emergency Contacts List
            if emergencyContacts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No emergency contacts")
                            .font(.headline)
                        Text("Add people you should always be able to reach")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(emergencyContacts) { contact in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Text(String(contact.fullName.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(contact.fullName)
                                    .fontWeight(.medium)
                                if let phone = contact.phoneNumber {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .onDelete(perform: removeContacts)
                } header: {
                    Text("Emergency Contacts")
                }
            }
            
            // 911 Note
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.red)
                    Text("911 is always accessible")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("Emergency services can never be blocked.")
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddContact) {
            AddEmergencyContactSheet(emergencyContacts: $emergencyContacts) {
                saveContacts()
            }
        }
        .onAppear {
            loadContacts()
        }
    }
    
    private func loadContacts() {
        emergencyContacts = persistence.loadBlockedContacts().filter { $0.isEmergencyContact }
    }
    
    private func saveContacts() {
        // Get all contacts and update emergency status
        var allContacts = persistence.loadBlockedContacts()
        
        // Remove old emergency contacts
        allContacts.removeAll { $0.isEmergencyContact }
        
        // Add new emergency contacts
        allContacts.append(contentsOf: emergencyContacts)
        
        persistence.saveBlockedContacts(allContacts)
        
        // Update user settings
        var settings = persistence.loadUserSettings()
        settings.emergencyContactIDs = emergencyContacts.map { $0.id }
        persistence.saveUserSettings(settings)
    }
    
    private func removeContacts(at offsets: IndexSet) {
        emergencyContacts.remove(atOffsets: offsets)
        saveContacts()
    }
}

struct AddEmergencyContactSheet: View {
    @Binding var emergencyContacts: [BlockedContact]
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactsService = ContactsService.shared
    @State private var searchText: String = ""
    @State private var isLoading = true
    
    var filteredContacts: [BlockedContact] {
        let available = contactsService.contacts.filter { contact in
            !emergencyContacts.contains { $0.id == contact.id }
        }
        
        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if contactsService.authorizationStatus != .authorized {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Contacts Access Required")
                            .font(.headline)
                        
                        Text("We need access to your contacts to let you select emergency contacts.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Grant Access") {
                            Task {
                                await contactsService.requestAccess()
                                if contactsService.authorizationStatus == .authorized {
                                    await loadContacts()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Loading contacts...")
                } else {
                    List {
                        Section {
                            ForEach(filteredContacts) { contact in
                                Button {
                                    addContact(contact)
                                } label: {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                            
                                            Text(String(contact.fullName.prefix(1)).uppercased())
                                                .font(.headline)
                                                .foregroundColor(.green)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(contact.fullName)
                                                .foregroundColor(.primary)
                                            if let phone = contact.phoneNumber {
                                                Text(phone)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        } header: {
                            Text("Select Emergency Contact")
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
            }
            .navigationTitle("Add Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if contactsService.authorizationStatus == .authorized {
                    await loadContacts()
                }
            }
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        _ = await contactsService.fetchAllContacts()
        isLoading = false
    }
    
    private func addContact(_ contact: BlockedContact) {
        var newContact = contact
        newContact.isEmergencyContact = true
        emergencyContacts.append(newContact)
        onSave()
    }
}

#Preview {
    NavigationStack {
        EmergencyContactsView()
    }
}
