import AppIntents
import SwiftUI
struct WhoToReachOutIntent: AppIntent {
    static let title: LocalizedStringResource = "Who should I reach out to?"
    static let description = IntentDescription("Echo analyzes your relationships and suggests who to contact.")
    static let openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let suggestion = "\nHey! I looked at your relationships:\n\nRed alert: Marcus — 45 days no contact\nYellow: James — 28 days no contact\nGreen: Sarah — recently contacted\n\nSuggest handling Marcus first. Want me to draft a message?"
        return .result(dialog: IntentDialog(suggestion))
    }
}
struct LogInteractionIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an interaction"
    static let description = IntentDescription("Record that you reached out to someone.")
    static let openAppWhenRun: Bool = true
    @Parameter(title: "Contact name") var contactName: String
    @Parameter(title: "Interaction type") var interactionType: String
    func perform() async throws -> some IntentResult & ProvidesDialog { return .result(dialog: IntentDialog("Logged: \(interactionType) with \(contactName) saved")) }
}
struct RelationshipHealthIntent: AppIntent {
    static let title: LocalizedStringResource = "How are my relationships?"
    static let description = IntentDescription("Get a quick health summary of your relationships.")
    static let openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = "\nRelationship Health Report:\n\n8 relationships healthy\n3 need attention\n1 critical\n\nOverall good, but Alex needs attention soon.\nCurrent streak: 12 days"
        return .result(dialog: IntentDialog(summary))
    }
}
struct EchoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WhoToReachOutIntent(), phrases: ["Who should I reach out to with \(.applicationName)", "who to contact in \(.applicationName)", "\(.applicationName) suggest someone", "今天该联系谁在 \(.applicationName)"], shortTitle: "Who to reach out to", systemImageName: "wave.3.right")
        AppShortcut(intent: RelationshipHealthIntent(), phrases: ["How are my relationships in \(.applicationName)", "relationship health in \(.applicationName)", "关系健康在 \(.applicationName)"], shortTitle: "Relationship health", systemImageName: "heart.text.square")
        AppShortcut(intent: LogInteractionIntent(), phrases: ["Log interaction in \(.applicationName)", "record contact in \(.applicationName)", "记录互动在 \(.applicationName)"], shortTitle: "Log interaction", systemImageName: "checkmark.bubble")
    }
}