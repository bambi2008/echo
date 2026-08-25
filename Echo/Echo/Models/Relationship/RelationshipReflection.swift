import Foundation
import SwiftData

@Model
final class RelationshipReflection {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var themeRawValue: String
    var previousIntentRawValue: String?
    var selectedIntentRawValue: String?
    var contextText: String?
    var outcomeRawValue: String?
    var journeyID: UUID?
    var contact: EchoContact?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        theme: ReflectionTheme,
        previousIntent: RelationshipIntent? = nil,
        selectedIntent: RelationshipIntent? = nil,
        contextText: String? = nil,
        outcome: ReflectionOutcome? = nil,
        journeyID: UUID? = nil,
        contact: EchoContact? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.themeRawValue = theme.rawValue
        self.previousIntentRawValue = previousIntent?.rawValue
        self.selectedIntentRawValue = selectedIntent?.rawValue
        self.contextText = contextText
        self.outcomeRawValue = outcome?.rawValue
        self.journeyID = journeyID
        self.contact = contact
    }

    var theme: ReflectionTheme { ReflectionTheme(rawValue: themeRawValue) ?? .ongoing }
    var previousIntent: RelationshipIntent? { previousIntentRawValue.flatMap(RelationshipIntent.init(rawValue:)) }
    var selectedIntent: RelationshipIntent? { selectedIntentRawValue.flatMap(RelationshipIntent.init(rawValue:)) }
    var outcome: ReflectionOutcome? { outcomeRawValue.flatMap(ReflectionOutcome.init(rawValue:)) }
}
