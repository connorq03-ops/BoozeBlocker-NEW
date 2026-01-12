import SwiftUI

/// View for previewing and potentially delaying messages to blocked contacts
struct MessagePreviewView: View {
    let contactName: String
    let onSendAnyway: () -> Void
    let onCancel: () -> Void
    let onSaveForLater: () -> Void
    
    @State private var messageText: String = ""
    @State private var showSobrietyTest = false
    @State private var delayHours: Int = 8
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning header
                warningHeader
                
                // Message composer
                messageComposer
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Message to \(contactName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showSobrietyTest) {
                SobrietyTestView { passed in
                    showSobrietyTest = false
                    if passed {
                        onSendAnyway()
                    }
                }
            }
        }
    }
    
    private var warningHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
            }
            
            Text("This contact is blocked")
                .font(.headline)
            
            Text("You added \(contactName) to your block list. Are you sure you want to send this message?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
    }
    
    private var messageComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $messageText)
                .frame(minHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            if !messageText.isEmpty {
                Text("\(messageText.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save for later option
            VStack(spacing: 8) {
                Text("Send later when you're sober?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Delay:")
                    Picker("Delay", selection: $delayHours) {
                        Text("4 hours").tag(4)
                        Text("8 hours").tag(8)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                    }
                    .pickerStyle(.segmented)
                }
                
                Button {
                    onSaveForLater()
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Save & Send in \(delayHours) Hours")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
            )
            
            // Send anyway (requires test)
            Button {
                showSobrietyTest = true
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                    Text("Send Now (Requires Test)")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }
            
            // Don't send
            Button {
                onCancel()
            } label: {
                HStack {
                    Image(systemName: "xmark")
                    Text("Don't Send")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

/// Model for delayed messages
struct DelayedMessage: Codable, Identifiable {
    let id: UUID
    let contactId: String
    let contactName: String
    let messageText: String
    let createdAt: Date
    let scheduledSendTime: Date
    var isSent: Bool
    var isCancelled: Bool
    
    init(
        contactId: String,
        contactName: String,
        messageText: String,
        delayHours: Int
    ) {
        self.id = UUID()
        self.contactId = contactId
        self.contactName = contactName
        self.messageText = messageText
        self.createdAt = Date()
        self.scheduledSendTime = Date().addingTimeInterval(Double(delayHours) * 60 * 60)
        self.isSent = false
        self.isCancelled = false
    }
}

/// Service for managing delayed messages
class DelayedMessageService: ObservableObject {
    static let shared = DelayedMessageService()
    
    @Published private(set) var pendingMessages: [DelayedMessage] = []
    
    private init() {
        loadMessages()
    }
    
    func scheduleMessage(_ message: DelayedMessage) {
        pendingMessages.append(message)
        saveMessages()
        
        // Schedule notification
        NotificationService.shared.scheduleDelayedMessageReminder(message)
    }
    
    func cancelMessage(id: UUID) {
        if let index = pendingMessages.firstIndex(where: { $0.id == id }) {
            pendingMessages[index].isCancelled = true
            saveMessages()
        }
    }
    
    func markAsSent(id: UUID) {
        if let index = pendingMessages.firstIndex(where: { $0.id == id }) {
            pendingMessages[index].isSent = true
            saveMessages()
        }
    }
    
    func getReadyToSendMessages() -> [DelayedMessage] {
        let now = Date()
        return pendingMessages.filter {
            !$0.isSent && !$0.isCancelled && $0.scheduledSendTime <= now
        }
    }
    
    private func saveMessages() {
        if let data = try? JSONEncoder().encode(pendingMessages) {
            UserDefaults.standard.set(data, forKey: "delayedMessages")
        }
    }
    
    private func loadMessages() {
        if let data = UserDefaults.standard.data(forKey: "delayedMessages"),
           let messages = try? JSONDecoder().decode([DelayedMessage].self, from: data) {
            pendingMessages = messages
        }
    }
}

extension NotificationService {
    func scheduleDelayedMessageReminder(_ message: DelayedMessage) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Message Ready to Send"
        content.body = "Your message to \(message.contactName) is ready. Would you like to send it now?"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: message.scheduledSendTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "delayed_message_\(message.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

#Preview {
    MessagePreviewView(
        contactName: "John",
        onSendAnyway: {},
        onCancel: {},
        onSaveForLater: {}
    )
}
