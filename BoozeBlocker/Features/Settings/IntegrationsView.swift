import SwiftUI

/// Settings view for third-party integrations
struct IntegrationsView: View {
    @StateObject private var ouraService = OuraService.shared
    @StateObject private var plaidService = PlaidService.shared
    @StateObject private var locationService = LocationService.shared
    
    var body: some View {
        List {
            // Oura Ring Section
            Section {
                IntegrationRow(
                    icon: "heart.circle.fill",
                    title: "Oura Ring",
                    subtitle: ouraService.isConnected ? "Connected" : "Auto-detect drinking via biometrics",
                    isConnected: ouraService.isConnected,
                    color: .purple
                ) {
                    if ouraService.isConnected {
                        ouraService.disconnect()
                    } else {
                        connectOura()
                    }
                }
                
                if ouraService.isConnected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle("Auto-activate when drinking detected", isOn: .constant(true))
                            .font(.subheadline)
                        
                        Toggle("Send confirmation before activating", isOn: .constant(true))
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Wearables")
            } footer: {
                Text("Oura Ring can detect drinking through changes in heart rate variability, resting heart rate, and body temperature.")
            }
            
            // Credit Card Section
            Section {
                IntegrationRow(
                    icon: "creditcard.fill",
                    title: "Credit Card Alerts",
                    subtitle: plaidService.isConnected ? "\(plaidService.linkedAccounts.count) account(s) linked" : "Auto-activate on bar charges",
                    isConnected: plaidService.isConnected,
                    color: .green
                ) {
                    if plaidService.isConnected {
                        plaidService.disconnect()
                    } else {
                        connectPlaid()
                    }
                }
                
                if plaidService.isConnected {
                    ForEach(plaidService.linkedAccounts) { account in
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(.secondary)
                            Text(account.displayName)
                                .font(.subheadline)
                        }
                        .padding(.leading, 8)
                    }
                }
            } header: {
                Text("Financial")
            } footer: {
                Text("Securely connect your cards via Plaid to detect charges at bars and liquor stores. We only see merchant categories, not transaction details.")
            }
            
            // Location Section
            Section {
                IntegrationRow(
                    icon: "location.fill",
                    title: "Location Triggers",
                    subtitle: locationService.authorizationStatus == .authorizedAlways ? "Enabled" : "Activate at saved locations",
                    isConnected: locationService.authorizationStatus == .authorizedAlways,
                    color: .blue
                ) {
                    if locationService.authorizationStatus != .authorizedAlways {
                        locationService.requestAuthorization()
                    }
                }
                
                if locationService.authorizationStatus == .authorizedAlways {
                    NavigationLink {
                        SavedLocationsView()
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.blue)
                            Text("Manage Saved Locations")
                            Spacer()
                            Text("\(locationService.getSavedLocations().count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Automatically activate protection when you arrive at saved locations like bars or clubs.")
            }
            
            // Privacy Note
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PrivacyNoteRow(
                        icon: "lock.shield.fill",
                        text: "All integration data is processed locally"
                    )
                    
                    PrivacyNoteRow(
                        icon: "eye.slash.fill",
                        text: "We never store your financial transactions"
                    )
                    
                    PrivacyNoteRow(
                        icon: "location.slash.fill",
                        text: "Location data never leaves your device"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Privacy")
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func connectOura() {
        // In production, would open Oura OAuth flow
        print("Opening Oura connection flow...")
    }
    
    private func connectPlaid() {
        // In production, would open Plaid Link
        print("Opening Plaid Link...")
    }
}

struct IntegrationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isConnected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                action()
            } label: {
                Text(isConnected ? "Disconnect" : "Connect")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isConnected ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(isConnected ? .red : .blue)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PrivacyNoteRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct SavedLocationsView: View {
    @StateObject private var locationService = LocationService.shared
    @State private var showAddLocation = false
    
    var body: some View {
        List {
            if locationService.getSavedLocations().isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No saved locations")
                            .font(.headline)
                        
                        Text("Add bars, clubs, or other places where you drink")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(locationService.getSavedLocations()) { location in
                        HStack {
                            Image(systemName: location.locationType.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .fontWeight(.medium)
                                Text(location.locationType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if location.isEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let locations = locationService.getSavedLocations()
                            locationService.removeLocation(id: locations[index].id)
                        }
                    }
                } header: {
                    Text("Saved Locations")
                }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationView()
        }
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared
    
    @State private var name = ""
    @State private var locationType: LocationType = .bar
    @State private var radius: Double = 100
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Location Name", text: $name)
                    
                    Picker("Type", selection: $locationType) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    VStack(alignment: .leading) {
                        Text("Trigger Radius: \(Int(radius))m")
                        Slider(value: $radius, in: 50...500, step: 50)
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("Protection will activate when you enter this radius")
                }
                
                Section {
                    Text("📍 In the full app, you would select a location on a map or search for an address.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveLocation() {
        // In production, would get actual coordinates from map selection
        let location = SavedLocation(
            name: name,
            latitude: 30.2672, // Placeholder (Austin, TX)
            longitude: -97.7431,
            radius: radius,
            locationType: locationType
        )
        
        locationService.addLocation(location)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        IntegrationsView()
    }
}
