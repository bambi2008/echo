import Foundation

enum OngoingReflectionQuestionBank {
    static let questions: [String] = [
        String(localized: "Who has unexpectedly come to mind lately?"),
        String(localized: "Is there a relationship that is slowly fading?"),
        String(localized: "Who might need your care lately?"),
        String(localized: "If you reached out to only one person this week, who would it be?"),
        String(localized: "Which important person keeps being left for later?"),
        String(localized: "Is any relationship taking more energy than you want to give it?"),
        String(localized: "Who no longer fits the rhythm you used to have?"),
        String(localized: "Are you keeping this relationship because you cherish it, or because it is familiar?"),
        String(localized: "Who do you hope will still be beside you three years from now?"),
    ]

    static func question(completedReflectionCount: Int) -> String {
        questions[min(max(completedReflectionCount, 0), questions.count - 1)]
    }
}
