import SwiftUI

struct TypingTestView: View {
    let phrase: String
    let onComplete: (Bool) -> Void
    
    @State private var userInput: String = ""
    @State private var attempts: Int = 0
    @State private var showError: Bool = false
    @State private var isCorrect: Bool = false
    
    private let maxAttempts = 2
    
    var reversedPhrase: String {
        String(phrase.reversed())
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Typing Challenge")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Type this phrase backwards")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Phrase to type
            VStack(spacing: 16) {
                Text("Type this backwards:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\"\(phrase)\"")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                
                // Input field
                TextField("Type here...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                // Character count
                HStack {
                    Text("\(userInput.count) / \(reversedPhrase.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !userInput.isEmpty {
                        let matchCount = countMatchingCharacters()
                        Text("\(matchCount) correct")
                            .font(.caption)
                            .foregroundColor(matchCount == reversedPhrase.count ? .green : .orange)
                    }
                }
                
                // Error message
                if showError {
                    Text("Incorrect! \(maxAttempts - attempts) attempt\(maxAttempts - attempts == 1 ? "" : "s") remaining")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                // Success message
                if isCorrect {
                    Text("Correct! Well done.")
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
                    .background(userInput.isEmpty ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(userInput.isEmpty || isCorrect)
            
            // Hint
            Text("Hint: \"\(phrase)\" backwards is \"\(reversedPhrase.prefix(3))...\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func countMatchingCharacters() -> Int {
        let input = userInput.lowercased()
        let target = reversedPhrase.lowercased()
        
        var count = 0
        for (inputChar, targetChar) in zip(input, target) {
            if inputChar == targetChar {
                count += 1
            }
        }
        return count
    }
    
    private func checkAnswer() {
        let cleanedInput = userInput.trimmingCharacters(in: .whitespaces).lowercased()
        let cleanedTarget = reversedPhrase.lowercased()
        
        if cleanedInput == cleanedTarget {
            isCorrect = true
            showError = false
            HapticService.shared.success()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete(true)
            }
        } else {
            attempts += 1
            showError = true
            userInput = ""
            HapticService.shared.error()
            
            if attempts >= maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete(false)
                }
            }
        }
    }
}

#Preview {
    TypingTestView(phrase: "I am making a conscious decision") { passed in
        print("Passed: \(passed)")
    }
}
