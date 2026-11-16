import SwiftUI

struct MessagePreviewDemoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MessagePreviewView(
            contactName: "Preview contact",
            onSendAnyway: { dismiss() },
            onCancel: { dismiss() },
            onSaveForLater: { dismiss() }
        )
    }
}

struct ExtraSobrietyTestsView: View {
    var body: some View {
        List {
            if FeatureFlags.extraSobrietyTests.isEnabled() {
                NavigationLink("Math") {
                    MathTestView(question: "12 + 5 = ?", correctAnswer: 17, onComplete: { _ in })
                }
                NavigationLink("Typing") {
                    TypingTestView(phrase: "I am making a conscious decision", onComplete: { _ in })
                }
                NavigationLink("Reaction") { ReactionTestView(onComplete: { _ in }) }
                NavigationLink("Balance") { BalanceTestView(onComplete: { _ in }) }
            }
        }
        .navigationTitle("Practice Tests")
    }
}
