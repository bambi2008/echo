import Foundation
import SwiftData

@MainActor
struct RelationshipJourneyService {
    func activeJourney(in context: ModelContext) throws -> ReflectionJourney? {
        let journeys = try context.fetch(
            FetchDescriptor<ReflectionJourney>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
        return journeys.first(where: { !$0.isComplete })
    }

    @discardableResult
    func startJourney(in context: ModelContext, now: Date = .now) throws -> ReflectionJourney {
        if let active = try activeJourney(in: context) { return active }
        let journey = ReflectionJourney(startedAt: now)
        context.insert(journey)
        try context.save()
        return journey
    }

    @discardableResult
    func restartJourney(in context: ModelContext, now: Date = .now) throws -> ReflectionJourney {
        let journey = ReflectionJourney(startedAt: now)
        context.insert(journey)
        try context.save()
        return journey
    }

    @discardableResult
    func review(
        contact: EchoContact,
        intent: RelationshipIntent?,
        contextText: String?,
        theme: ReflectionTheme,
        journey: ReflectionJourney?,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RelationshipReflection {
        let cleanedContext = contextText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflection = RelationshipReflection(
            createdAt: now,
            theme: theme,
            previousIntent: contact.relationshipIntent,
            selectedIntent: intent,
            contextText: cleanedContext?.isEmpty == false ? cleanedContext : nil,
            journeyID: journey?.id,
            contact: contact
        )
        context.insert(reflection)
        contact.relationshipReflections.append(reflection)
        contact.relationshipIntent = intent
        contact.relationshipContext = cleanedContext?.isEmpty == false ? cleanedContext : contact.relationshipContext
        contact.lastRelationshipReviewAt = now
        contact.relationshipJourneyIncluded = true
        try context.save()
        return reflection
    }

    @discardableResult
    func planAction(
        for contact: EchoContact?,
        type: RelationshipActionType,
        note: String? = nil,
        plannedFor: Date? = nil,
        reflectionID: UUID? = nil,
        journey: ReflectionJourney?,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RelationshipAction {
        let action = RelationshipAction(
            createdAt: now,
            plannedFor: plannedFor,
            type: type,
            status: type == .none ? .skipped : .planned,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            reflectionID: reflectionID,
            journeyID: journey?.id,
            contact: contact
        )
        context.insert(action)
        contact?.relationshipActions.append(action)
        try context.save()
        return action
    }

    func completeAction(_ action: RelationshipAction, in context: ModelContext, now: Date = .now) throws {
        action.status = .completed
        action.completedAt = now
        try context.save()
    }

    func updateContext(
        for contact: EchoContact,
        text: String?,
        journey: ReflectionJourney?,
        in context: ModelContext
    ) throws {
        let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = cleaned?.isEmpty == false ? cleaned : nil
        contact.relationshipContext = value
        let latest = contact.relationshipReflections
            .filter { journey == nil || $0.journeyID == journey?.id }
            .max { $0.createdAt < $1.createdAt }
        latest?.contextText = value
        try context.save()
    }

    func cancelAction(_ action: RelationshipAction, in context: ModelContext) throws {
        action.status = .skipped
        try context.save()
    }

    @discardableResult
    func recordOutcome(
        _ outcome: ReflectionOutcome,
        for action: RelationshipAction,
        theme: ReflectionTheme = .ongoing,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RelationshipReflection? {
        guard let contact = action.contact else { return nil }
        let reflection = RelationshipReflection(
            createdAt: now,
            theme: theme,
            previousIntent: contact.relationshipIntent,
            selectedIntent: contact.relationshipIntent,
            outcome: outcome,
            journeyID: action.journeyID,
            contact: contact
        )
        context.insert(reflection)
        contact.relationshipReflections.append(reflection)
        try context.save()
        return reflection
    }

    func completeWeek(_ journey: ReflectionJourney, in context: ModelContext, now: Date = .now) throws {
        let theme = journey.currentTheme
        if !journey.completedThemeRawValues.contains(theme.rawValue) {
            journey.completedThemeRawValues.append(theme.rawValue)
        }
        journey.selectedContactIdentifiers = []
        journey.draftIntentValues = []
        journey.draftContextValues = []
        journey.activeStepRawValue = nil
        if journey.completedThemeRawValues.count >= 4 {
            journey.completedAt = now
            journey.currentWeekIndex = 4
        } else {
            journey.currentWeekIndex = min(4, journey.currentWeekIndex + 1)
        }
        try context.save()
    }
}
