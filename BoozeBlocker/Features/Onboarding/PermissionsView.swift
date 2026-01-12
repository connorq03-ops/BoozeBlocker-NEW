import SwiftUI

struct PermissionsView: View {
    @Binding var hasGrantedPermissions: Bool
    
    @StateObject private var contactsService = ContactsService.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var contactsGranted = false
    @State private var screenTimeGranted = false
    @State private var notificationsGranted = false
    @State private var isRequestingPermission = false
    
    var allPermissionsGranted: Bool {
        contactsGranted && screenTimeGranted && notificationsGranted
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Booze Blocker needs a few permissions to protect you effectively")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "person.crop.circle.fill",
                    title: "Contacts",
                    description: "To select which contacts to block",
                    isGranted: contactsGranted,
                    isLoading: isRequestingPermission
                ) {
                    await requestContactsPermission()
                }
                
                PermissionCard(
                    icon: "hourglass",
                    title: "Screen Time",
                    description: "To block apps while you're protected",
                    isGranted: screenTimeGranted,
                    isLoading: isRequestingPermission
                ) {
                    await requestScreenTimePermission()
                }
                
                PermissionCard(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "To alert you about blocked attempts",
                    isGranted: notificationsGranted,
                    isLoading: isRequestingPermission
                ) {
                    await requestNotificationPermission()
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            VStack(spacing: 12) {
                Button {
                    hasGrantedPermissions = true
                } label: {
                    Text(allPermissionsGranted ? "Continue" : "Skip for Now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(allPermissionsGranted ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                if !allPermissionsGranted {
                    Text("Some features may not work without all permissions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
    
    private func requestContactsPermission() async {
        isRequestingPermission = true
        contactsGranted = await contactsService.requestAccess()
        isRequestingPermission = false
    }
    
    private func requestScreenTimePermission() async {
        isRequestingPermission = true
        screenTimeGranted = await screenTimeService.requestAuthorization()
        isRequestingPermission = false
    }
    
    private func requestNotificationPermission() async {
        isRequestingPermission = true
        notificationsGranted = await notificationService.requestAuthorization()
        isRequestingPermission = false
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isLoading: Bool
    let action: () async -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.title3)
                    .foregroundColor(isGranted ? .green : .blue)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button
            if !isGranted {
                Button {
                    Task {
                        await action()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Allow")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

#Preview {
    PermissionsView(hasGrantedPermissions: .constant(false))
}
