import SwiftUI

struct DurationPickerSheet: View {
    let onSelect: (TimeInterval?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let durations: [(String, TimeInterval?)] = [
        ("Until 8:00 AM", calculateTimeUntil8AM()),
        ("4 hours", 4 * 60 * 60),
        ("6 hours", 6 * 60 * 60),
        ("8 hours", 8 * 60 * 60),
        ("Until I stop", nil)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How long do you need protection?")
                    .font(.headline)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    ForEach(durations, id: \.0) { duration in
                        Button {
                            onSelect(duration.1)
                        } label: {
                            HStack {
                                Text(duration.0)
                                    .fontWeight(.medium)
                                Spacer()
                                if duration.1 == nil {
                                    Image(systemName: "infinity")
                                } else {
                                    Image(systemName: "clock")
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text("You'll need to pass a sobriety test to stop early")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("Select Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private static func calculateTimeUntil8AM() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        components.minute = 0
        components.second = 0
        
        var target = calendar.date(from: components) ?? now
        
        // If 8 AM has already passed today, use tomorrow's 8 AM
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        
        return target.timeIntervalSince(now)
    }
}

#Preview {
    DurationPickerSheet { duration in
        print("Selected: \(String(describing: duration))")
    }
}
