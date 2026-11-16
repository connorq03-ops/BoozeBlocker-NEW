import SwiftUI

struct MorningSummaryDestination: View {
    let session: ProtectionSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MorningSummaryView(session: session, onDismiss: { dismiss() })
    }
}

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
                    PracticeTestDestination { complete in
                        MathTestView(question: "12 + 5 = ?", correctAnswer: 17, onComplete: complete)
                    }
                }
                NavigationLink("Typing") {
                    PracticeTestDestination { complete in
                        TypingTestView(phrase: "I am making a conscious decision", onComplete: complete)
                    }
                }
                NavigationLink("Reaction") {
                    PracticeTestDestination { complete in ReactionTestView(onComplete: complete) }
                }
                NavigationLink("Balance") {
                    PracticeTestDestination { complete in BalanceTestView(onComplete: complete) }
                }
            }
        }
        .navigationTitle("Practice Tests")
    }
}

private struct PracticeTestDestination<Content: View>: View {
    let content: (@escaping (Bool) -> Void) -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content { _ in dismiss() }
    }
}
