import Foundation

struct RelationshipGuidance: Identifiable, Equatable {
    enum Kind: Equatable {
        case plannedAction
        case rhythmCheck
    }
    let id: String
    let contactIdentifier: String
    let kind: Kind
    let explanation: String
}

struct LocalRelationshipInsight: Identifiable, Equatable {
    enum Kind: Equatable {
        case intentionAheadOfAction
        case spaceMismatch
        case intentChanged
        case journeyProgress
        case insufficientData
    }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let contactIdentifiers: [String]
}

enum RelationshipGuidanceEngine {
    static func guidance(for contacts: [EchoContact], now: Date = .now) -> [RelationshipGuidance] {
        var output: [RelationshipGuidance] = []
        for contact in contacts where contact.relationshipJourneyIncluded {
            if let action = contact.relationshipActions
                .filter({ $0.status == .planned })
                .sorted(by: { ($0.plannedFor ?? $0.createdAt) < ($1.plannedFor ?? $1.createdAt) })
                .first {
                output.append(RelationshipGuidance(
                    id: "action:\(action.id)",
                    contactIdentifier: contact.systemIdentifier,
                    kind: .plannedAction,
                    explanation: String(localized: "You chose this action in Echo. Is now a good moment?")
                ))
                continue
            }
            guard contact.relationshipIntent != .pause,
                  contact.relationshipIntent != .light || contact.desiredCadenceDays != nil,
                  [.deepen, .maintain, .light].contains(contact.relationshipIntent),
                  let cadence = contact.desiredCadenceDays,
                  let lastReview = contact.lastRelationshipReviewAt
            else { continue }
            let elapsed = Calendar.current.dateComponents([.day], from: lastReview, to: now).day ?? 0
            if elapsed >= cadence {
                output.append(RelationshipGuidance(
                    id: "rhythm:\(contact.systemIdentifier)",
                    contactIdentifier: contact.systemIdentifier,
                    kind: .rhythmCheck,
                    explanation: String(localized: "This is a rhythm you chose. Would you like to adjust it or do something small?")
                ))
            }
        }
        return output
    }

    static func insights(
        contacts: [EchoContact],
        journeys: [ReflectionJourney]
    ) -> [LocalRelationshipInsight] {
        let reviewed = contacts.filter { $0.lastRelationshipReviewAt != nil }
        guard !reviewed.isEmpty else {
            return [LocalRelationshipInsight(
                id: "insufficient",
                kind: .insufficientData,
                title: String(localized: "There is not enough reflection data yet"),
                detail: String(localized: "After you review a few relationships and record actions in Echo, patterns may begin to appear. There is nothing to adjust yet."),
                contactIdentifiers: []
            )]
        }

        var insights: [LocalRelationshipInsight] = []
        let deepenWithoutActions = reviewed.filter {
            $0.relationshipIntent == .deepen && !$0.relationshipActions.contains(where: { $0.status == .completed })
        }
        if !deepenWithoutActions.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "deepen-gap",
                kind: .intentionAheadOfAction,
                title: String(localized: "Your intention may be ahead of your actions"),
                detail: String(localized: "You placed \(deepenWithoutActions.count) people in Grow closer, but actions recorded in Echo have not followed yet. Would you like to choose one?"),
                contactIdentifiers: deepenWithoutActions.map(\.systemIdentifier)
            ))
        }

        let spaceWithActions = reviewed.filter { contact in
            contact.relationshipIntent == .pause && contact.relationshipActions.filter { $0.status == .completed }.count >= 2
        }
        if !spaceWithActions.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "space-gap",
                kind: .spaceMismatch,
                title: String(localized: "Your recent effort may not match the space you wanted"),
                detail: String(localized: "Echo contains several completed actions for relationships you placed in Give it space. Would you like to revisit that intention?"),
                contactIdentifiers: spaceWithActions.map(\.systemIdentifier)
            ))
        }

        let changed = reviewed.filter { contact in
            let values = contact.relationshipReflections.compactMap(\.selectedIntentRawValue)
            return Set(values).count > 1
        }
        if !changed.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "changed",
                kind: .intentChanged,
                title: String(localized: "Some relationships have changed shape"),
                detail: String(localized: "You changed your intention for \(changed.count) relationships. Would you like to look at what shifted?"),
                contactIdentifiers: changed.map(\.systemIdentifier)
            ))
        }

        let completedThemes = journeys.flatMap(\.completedThemeRawValues).count
        let deepenCount = reviewed.filter { $0.relationshipIntent == .deepen }.count
        let maintainCount = reviewed.filter { $0.relationshipIntent == .maintain }.count
        let lightCount = reviewed.filter { $0.relationshipIntent == .light }.count
        let pauseCount = reviewed.filter { $0.relationshipIntent == .pause }.count
        insights.append(LocalRelationshipInsight(
            id: "progress",
            kind: .journeyProgress,
            title: String(localized: "Your relationship map is becoming clearer"),
            detail: String(localized: "You have reviewed \(reviewed.count) relationships across \(completedThemes) weekly themes. The current map has \(deepenCount) Grow closer, \(maintainCount) Keep steady, \(lightCount) Keep it light, and \(pauseCount) Give it space. This reflects only what you chose and recorded in Echo. Would you like to adjust anything?"),
            contactIdentifiers: reviewed.map(\.systemIdentifier)
        ))
        return insights
    }
}
