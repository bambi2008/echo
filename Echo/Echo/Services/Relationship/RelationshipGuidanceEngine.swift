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
        let reviewed = contacts.filter { $0.isBusinessRelationship && ($0.lastRelationshipReviewAt != nil || !$0.notes.isEmpty || !$0.interactions.isEmpty) }
        guard !reviewed.isEmpty else {
            return [LocalRelationshipInsight(
                id: "insufficient",
                kind: .insufficientData,
                title: "Not enough business activity yet",
                detail: "Add a role, a note, or a completed follow-up to a few business contacts before asking Echo to find patterns.",
                contactIdentifiers: []
            )]
        }

        var insights: [LocalRelationshipInsight] = []
        let priorityWithoutActions = reviewed.filter {
            ($0.priority == .hot || $0.priority == .warm)
                && !$0.relationshipActions.contains(where: { $0.status == .completed })
        }
        if !priorityWithoutActions.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "deepen-gap",
                kind: .intentionAheadOfAction,
                title: "Priority contacts need a next step",
                detail: "\(priorityWithoutActions.count) Hot or Warm contacts have no completed follow-up recorded in Echo yet.",
                contactIdentifiers: priorityWithoutActions.map(\.systemIdentifier)
            ))
        }

        let cooling = reviewed.filter { contact in
            guard let days = contact.daysSinceContact else { return false }
            return days >= 60
        }
        if !cooling.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "space-gap",
                kind: .spaceMismatch,
                title: "Business contacts are cooling",
                detail: "\(cooling.count) commercial contacts have no recorded activity for 60 days or more. Review Pipeline and set a next action where needed.",
                contactIdentifiers: cooling.map(\.systemIdentifier)
            ))
        }

        let unclassified = reviewed.filter { $0.businessRole == .other }
        if !unclassified.isEmpty {
            insights.append(LocalRelationshipInsight(
                id: "unclassified",
                kind: .intentChanged,
                title: "Some contacts need a business role",
                detail: "Classify \(unclassified.count) contacts as prospects, clients, partners, or another role so Echo can rank them accurately.",
                contactIdentifiers: unclassified.map(\.systemIdentifier)
            ))
        }

        // Keep a useful compatibility signal for records created by the
        // previous reflection flow. The current UI does not expose those
        // personal concepts, but an existing commercial contact may still
        // carry a chosen intent and needs a next business action.
        let legacyIntentContacts = reviewed.filter {
            $0.relationshipJourneyIncluded && $0.relationshipIntent != nil
        }
        if !legacyIntentContacts.isEmpty && !insights.contains(where: { $0.kind == .intentionAheadOfAction }) {
            insights.append(LocalRelationshipInsight(
                id: "legacy-intent",
                kind: .intentionAheadOfAction,
                title: "Business intent needs a next step",
                detail: "(legacyIntentContacts.count) commercial contacts have a recorded intent but no new follow-up decision in the business workspace.",
                contactIdentifiers: legacyIntentContacts.map(\.systemIdentifier)
            ))
        }

        let roleSummary = BusinessContactRole.allCases.compactMap { role -> String? in
            let count = reviewed.filter { $0.businessRole == role }.count
            return count > 0 ? "\(count) \(role.title)" : nil
        }.joined(separator: ", ")
        insights.append(LocalRelationshipInsight(
            id: "progress",
            kind: .journeyProgress,
            title: "Your business network is taking shape",
            detail: "Echo has context for \(reviewed.count) commercial contacts: \(roleSummary).",
            contactIdentifiers: reviewed.map(\.systemIdentifier)
        ))
        return insights
    }
}
