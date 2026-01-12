import SwiftUI

struct HelpSupportView: View {
    var body: some View {
        List {
            // FAQ Section
            Section {
                FAQRow(
                    question: "How does app blocking work?",
                    answer: "When you activate protection, Booze Blocker uses iOS Screen Time to prevent access to your selected apps. You'll see a shield screen when you try to open them."
                )
                
                FAQRow(
                    question: "Can I still receive calls and texts?",
                    answer: "Yes! Booze Blocker only blocks outgoing communication to your blocked contacts. You can always receive calls and texts from anyone."
                )
                
                FAQRow(
                    question: "What if there's an emergency?",
                    answer: "911 is always accessible. You can also designate emergency contacts who are never blocked, even when protection is active."
                )
                
                FAQRow(
                    question: "How do I deactivate protection early?",
                    answer: "You'll need to pass a sobriety test (math problem or typing challenge). This helps ensure you're thinking clearly before disabling protection."
                )
                
                FAQRow(
                    question: "Is my data private?",
                    answer: "Absolutely. All your data is stored locally on your device. We never upload anything to any server. Your blocked contacts, apps, and history never leave your phone."
                )
            } header: {
                Text("Frequently Asked Questions")
            }
            
            // Tips Section
            Section {
                TipRow(
                    icon: "lightbulb.fill",
                    title: "Set up before drinking",
                    description: "Activate protection before you start drinking for best results"
                )
                
                TipRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Block your ex",
                    description: "Add exes to your block list - you'll thank yourself in the morning"
                )
                
                TipRow(
                    icon: "calendar",
                    title: "Use scheduled protection",
                    description: "Set up automatic protection for regular nights out"
                )
                
                TipRow(
                    icon: "star.fill",
                    title: "Add emergency contacts",
                    description: "Make sure important people are always reachable"
                )
            } header: {
                Text("Pro Tips")
            }
            
            // Contact Section
            Section {
                Link(destination: URL(string: "mailto:support@boozeblocker.app")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Email Support")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://boozeblocker.app/help")!) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Help Center")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Get Help")
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
