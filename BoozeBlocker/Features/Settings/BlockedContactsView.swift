import SwiftUI

struct BlockedContactsView: View {
    @StateObject private var contactsService = ContactsService.shared
    @State private var blockedContacts: [BlockedContact] = []
    @State private var searchText: String = ""
    @State private var showAddContact = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundColor(.red)
                    Text("\(blockedContacts.count) contacts will be blocked")
                        .foregroundColor(.secondary)
                }
            }
            
            // Blocked Contacts List
            if blockedContacts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No blocked contacts")
                            .font(.headline)
                        Text("Add contacts you want to block while drinking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(blockedContacts) { contact in
                        HStack {
                            ContactAvatar(name: contact.fullName, category: contact.category)
                            
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
                            
                            CategoryBadge(category: contact.category)
                        }
                    }
                    .onDelete(perform: removeContacts)
                } header: {
                    Text("Blocked Contacts")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search blocked contacts")
        .navigationTitle("Blocked Contacts")
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
            AddContactSheet(blockedContacts: $blockedContacts) {
                saveContacts()
            }
        }
        .onAppear {
            loadContacts()
        }
    }
    
    private func loadContacts() {
        blockedContacts = persistence.loadBlockedContacts().filter { $0.isBlocked }
    }
    
    private func saveContacts() {
        persistence.saveBlockedContacts(blockedContacts)
        
        // Update user settings
        var settings = persistence.loadUserSettings()
        settings.blockedContactIDs = blockedContacts.map { $0.id }
        persistence.saveUserSettings(settings)
    }
    
    private func removeContacts(at offsets: IndexSet) {
        blockedContacts.remove(atOffsets: offsets)
        saveContacts()
    }
}

struct ContactAvatar: View {
    let name: String
    let category: ContactCategory
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(category.color).opacity(0.2))
                .frame(width: 40, height: 40)
            
            Text(String(name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundColor(Color(category.color))
        }
    }
}

struct CategoryBadge: View {
    let category: ContactCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(category.color).opacity(0.1))
        .foregroundColor(Color(category.color))
        .cornerRadius(8)
    }
}

struct AddContactSheet: View {
    @Binding var blockedContacts: [BlockedContact]
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactsService = ContactsService.shared
    @State private var searchText: String = ""
    @State private var selectedCategory: ContactCategory = .other
    @State private var isLoading = true
    
    var filteredContacts: [BlockedContact] {
        let available = contactsService.contacts.filter { contact in
            !blockedContacts.contains { $0.id == contact.id }
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
                    // Permission needed
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Contacts Access Required")
                            .font(.headline)
                        
                        Text("We need access to your contacts to let you select which ones to block while drinking.")
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
                        // Category picker
                        Section {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(ContactCategory.allCases, id: \.self) { category in
                                    Label(category.displayName, systemImage: category.icon)
                                        .tag(category)
                                }
                            }
                        } header: {
                            Text("Assign Category")
                        } footer: {
                            Text("Categorize contacts to organize your block list")
                        }
                        
                        // Contacts list
                        Section {
                            ForEach(filteredContacts) { contact in
                                Button {
                                    addContact(contact)
                                } label: {
                                    HStack {
                                        ContactAvatar(name: contact.fullName, category: selectedCategory)
                                        
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
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } header: {
                            Text("Select Contact to Block")
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
            }
            .navigationTitle("Add Contact")
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
        newContact.category = selectedCategory
        newContact.isBlocked = true
        blockedContacts.append(newContact)
        onSave()
    }
}

#Preview {
    NavigationStack {
        BlockedContactsView()
    }
}
