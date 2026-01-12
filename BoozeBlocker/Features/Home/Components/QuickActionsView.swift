import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    let onActivate: (TimeInterval?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Activate")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Until 8am",
                    icon: "sunrise.fill",
                    color: .orange
                ) {
                    onActivate(Date.timeUntil(hour: 8))
                }
                
                QuickActionButton(
                    title: "4 Hours",
                    icon: "clock.fill",
                    color: .blue
                ) {
                    onActivate(4 * 60 * 60)
                }
                
                QuickActionButton(
                    title: "Custom",
                    icon: "slider.horizontal.3",
                    color: .purple
                ) {
                    onActivate(nil) // Will show picker
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    QuickActionsView { duration in
        print("Activate for: \(String(describing: duration))")
    }
    .environmentObject(ProtectionManager.shared)
    .padding()
    .background(Color.gray.opacity(0.1))
}
