import SwiftUI

struct DurationPickerSheet: View {
    let onSelect: (TimeInterval?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let durations: [(String, TimeInterval?)] = [
        ("Until 8:00 AM", Date.timeUntil(hour: 8, minimumDuration: 3600)),
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
    
}

#Preview {
    DurationPickerSheet { duration in
        print("Selected: \(String(describing: duration))")
    }
}
