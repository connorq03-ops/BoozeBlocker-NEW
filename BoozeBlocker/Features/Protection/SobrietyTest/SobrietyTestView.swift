import SwiftUI

struct SobrietyTestView: View {
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var test: SobrietyTest
    @State private var userAnswer: String = ""
    @State private var attempts: Int = 0
    @State private var showError: Bool = false
    @State private var isCorrect: Bool = false
    
    private let maxAttempts = 3
    private let testService = SobrietyTestService.shared
    
    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
        let settings = PersistenceService.shared.loadUserSettings()
        _test = State(initialValue: SobrietyTestService.shared.generateTest(difficulty: settings.sobrietyTestDifficulty))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Sobriety Check")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Solve this to deactivate protection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Spacer()
                
                // Question
                VStack(spacing: 20) {
                    Text(test.question)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    
                    // Answer input
                    TextField("Your answer", text: $userAnswer)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .keyboardType(test.type == .math ? .numberPad : .default)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                    
                    // Error message
                    if showError {
                        Text("Incorrect! \(maxAttempts - attempts) attempts remaining")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    
                    // Success message
                    if isCorrect {
                        Text("Correct! Protection deactivated.")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Submit button
                Button {
                    checkAnswer()
                } label: {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userAnswer.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(userAnswer.isEmpty || isCorrect)
                .padding(.horizontal)
                
                // Attempts counter
                Text("Attempt \(attempts + 1) of \(maxAttempts)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func checkAnswer() {
        let correct = testService.validateAnswer(userAnswer, for: test)
        
        if correct {
            isCorrect = true
            showError = false
            
            // Delay before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete(true)
                dismiss()
            }
        } else {
            attempts += 1
            showError = true
            userAnswer = ""
            
            if attempts >= maxAttempts {
                // Failed all attempts
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete(false)
                    dismiss()
                }
            } else {
                // Generate new test for next attempt
                let settings = PersistenceService.shared.loadUserSettings()
                test = testService.generateTest(difficulty: settings.sobrietyTestDifficulty)
            }
        }
    }
}

#Preview {
    SobrietyTestView { passed in
        print("Test passed: \(passed)")
    }
}
