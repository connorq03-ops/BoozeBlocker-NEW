import XCTest
@testable import BoozeBlocker

final class SobrietyTestServiceTests: XCTestCase {
    private let service = SobrietyTestService.shared

    func testMathDifficultiesGenerateValidChallenges() throws {
        for difficulty: SobrietyTestDifficulty in [.easy, .medium, .hard] {
            let test = service.generateTest(difficulty: difficulty)
            XCTAssertEqual(test.type, .math)
            XCTAssertFalse(test.question.isEmpty)
            XCTAssertNil(test.expectedTypingAnswer)
            let answer = try XCTUnwrap(test.correctAnswer)
            XCTAssertTrue(service.validateAnswer(String(answer), for: test))
            XCTAssertFalse(service.validateAnswer(String(answer + 1), for: test))
        }
    }

    func testExtremeGeneratesTypingChallenge() throws {
        let test = service.generateTest(difficulty: .extreme)
        XCTAssertEqual(test.type, .typing)
        XCTAssertNil(test.correctAnswer)
        let answer = try XCTUnwrap(test.expectedTypingAnswer)
        XCTAssertFalse(answer.isEmpty)
        XCTAssertTrue(service.validateAnswer(answer, for: test))
    }

    func testMathValidationTrimsWhitespaceAndRejectsInvalidInput() {
        let test = SobrietyTest(type: .math, question: "12 + 5 = ?", correctAnswer: 17, expectedTypingAnswer: nil)
        XCTAssertTrue(service.validateAnswer(" 17 ", for: test))
        XCTAssertFalse(service.validateAnswer("18", for: test))
        XCTAssertFalse(service.validateAnswer("", for: test))
        XCTAssertFalse(service.validateAnswer("seventeen", for: test))
    }

    func testTypingValidationIgnoresCaseAndWhitespace() {
        let test = SobrietyTest(type: .typing, question: "Type backwards", correctAnswer: nil, expectedTypingAnswer: "olleH")
        XCTAssertTrue(service.validateAnswer(" OLLEH ", for: test))
        XCTAssertFalse(service.validateAnswer("Hello", for: test))
        XCTAssertFalse(service.validateAnswer("", for: test))
    }
}
