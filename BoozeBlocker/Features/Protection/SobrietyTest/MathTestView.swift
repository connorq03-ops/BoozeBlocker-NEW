import SwiftUI

struct MathTestView: View {
    let question: String
    let correctAnswer: Int
    let onComplete: (Bool) -> Void
    
    @State private var userAnswer: String = ""
    @State private var attempts: Int = 0
    @State private var showError: Bool = false
    @State private var isCorrect: Bool = false
    @State private var shakeError: Bool = false
    
    private let maxAttempts = 3
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Math Challenge")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Solve this to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Question
            VStack(spacing: 20) {
                Text(question)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                
                // Answer input
                HStack {
                    TextField("?", text: $userAnswer)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showError ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .shake(trigger: shakeError)
                }
                
                // Error message
                if showError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Incorrect! \(maxAttempts - attempts) attempt\(maxAttempts - attempts == 1 ? "" : "s") remaining")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
                
                // Success message
                if isCorrect {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Correct!")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Number pad (custom for better UX)
            NumberPad(value: $userAnswer)
            
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
            
            // Attempts counter
            Text("Attempt \(attempts + 1) of \(maxAttempts)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func checkAnswer() {
        guard let answer = Int(userAnswer) else {
            triggerError()
            return
        }
        
        if answer == correctAnswer {
            isCorrect = true
            showError = false
            HapticService.shared.success()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete(true)
            }
        } else {
            triggerError()
        }
    }
    
    private func triggerError() {
        attempts += 1
        showError = true
        shakeError.toggle()
        userAnswer = ""
        HapticService.shared.error()
        
        if attempts >= maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete(false)
            }
        }
    }
}

struct NumberPad: View {
    @Binding var value: String
    
    private let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { button in
                        NumberPadButton(title: button) {
                            handleTap(button)
                        }
                    }
                }
            }
        }
    }
    
    private func handleTap(_ button: String) {
        HapticService.shared.selection()
        
        if button == "⌫" {
            if !value.isEmpty {
                value.removeLast()
            }
        } else if !button.isEmpty {
            if value.count < 6 { // Limit to 6 digits
                value += button
            }
        }
    }
}

struct NumberPadButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 70, height: 50)
                .background(title.isEmpty ? Color.clear : Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
        .disabled(title.isEmpty)
        .foregroundColor(.primary)
    }
}

#Preview {
    MathTestView(
        question: "47 + 38 = ?",
        correctAnswer: 85
    ) { passed in
        print("Passed: \(passed)")
    }
}
