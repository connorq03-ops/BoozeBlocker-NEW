import Foundation

/// Service for generating and validating sobriety tests
class SobrietyTestService {
    static let shared = SobrietyTestService()
    
    private init() {}
    
    // MARK: - Test Generation
    
    /// Generate a sobriety test based on difficulty
    func generateTest(difficulty: SobrietyTestDifficulty) -> SobrietyTest {
        switch difficulty {
        case .easy:
            return generateMathTest(maxNumber: 20)
        case .medium:
            return generateMathTest(maxNumber: 100)
        case .hard:
            return generateMathTest(maxNumber: 500)
        case .extreme:
            return generateTypingTest()
        }
    }
    
    /// Validate a test answer
    func validateAnswer(_ answer: String, for test: SobrietyTest) -> Bool {
        switch test.type {
        case .math:
            guard let userAnswer = Int(answer.trimmingCharacters(in: .whitespaces)) else {
                return false
            }
            return userAnswer == test.correctAnswer
            
        case .typing:
            let cleanedAnswer = answer.trimmingCharacters(in: .whitespaces).lowercased()
            let cleanedExpected = test.expectedTypingAnswer?.lowercased() ?? ""
            return cleanedAnswer == cleanedExpected
        }
    }
    
    // MARK: - Private Methods
    
    private func generateMathTest(maxNumber: Int) -> SobrietyTest {
        let num1 = Int.random(in: 10...maxNumber)
        let num2 = Int.random(in: 10...maxNumber)
        let operation = MathOperation.allCases.randomElement() ?? .addition
        
        let (question, answer) = createMathQuestion(num1: num1, num2: num2, operation: operation)
        
        return SobrietyTest(
            type: .math,
            question: question,
            correctAnswer: answer,
            expectedTypingAnswer: nil
        )
    }
    
    private func createMathQuestion(num1: Int, num2: Int, operation: MathOperation) -> (String, Int) {
        switch operation {
        case .addition:
            return ("\(num1) + \(num2) = ?", num1 + num2)
        case .subtraction:
            // Ensure positive result
            let larger = max(num1, num2)
            let smaller = min(num1, num2)
            return ("\(larger) - \(smaller) = ?", larger - smaller)
        case .multiplication:
            // Use smaller numbers for multiplication
            let n1 = num1 % 15 + 2
            let n2 = num2 % 15 + 2
            return ("\(n1) × \(n2) = ?", n1 * n2)
        }
    }
    
    private func generateTypingTest() -> SobrietyTest {
        let phrases = [
            "I am making a conscious decision",
            "I am sober enough to proceed",
            "I take responsibility for my actions",
            "This message can wait until tomorrow",
            "I am thinking clearly right now"
        ]
        
        let phrase = phrases.randomElement() ?? phrases[0]
        let reversed = String(phrase.reversed())
        
        return SobrietyTest(
            type: .typing,
            question: "Type this phrase backwards:\n\"\(phrase)\"",
            correctAnswer: nil,
            expectedTypingAnswer: reversed
        )
    }
}

// MARK: - Supporting Types

/// A sobriety test challenge
struct SobrietyTest {
    let type: SobrietyTestType
    let question: String
    let correctAnswer: Int?           // For math tests
    let expectedTypingAnswer: String? // For typing tests
}

enum SobrietyTestType {
    case math
    case typing
}

enum MathOperation: CaseIterable {
    case addition
    case subtraction
    case multiplication
}
