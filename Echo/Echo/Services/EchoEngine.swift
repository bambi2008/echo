import Foundation
import SwiftData

@MainActor
enum EchoEngine {
    static func markReachedOut(
        to contact: EchoContact,
        type: InteractionType,
        note: String?,
        in context: ModelContext
    ) {
        let interaction = Interaction(type: type, summary: note ?? "", contact: contact)
        contact.interactions.append(interaction)
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contact.notes.append(EchoNote(content: note, contact: contact))
        }
        synchronizeActivity(for: contact)
        try? context.save()
    }

    /// Keeps the contact-level recency fields aligned with the editable
    /// interaction timeline. Incoming messages do not count as outreach.
    static func synchronizeActivity(for contact: EchoContact) {
        let outbound = contact.interactions.filter { interaction in
            guard interaction.isIncoming != true else { return false }
            // Legacy records may not have direction metadata; keep treating
            // those as outreach. Explicit internal notes must not affect
            // customer follow-up recency or counts.
            guard let direction = interaction.direction else { return true }
            return direction == .outbound
        }
        contact.lastReachedOut = outbound.map(\.date).max()
        contact.reachCount = outbound.count
    }

    @available(*, deprecated, message: "Use RelationshipGuidanceEngine for personal relationship guidance")
    static func attentionScore(for contact: EchoContact) -> Int {
        recencyAttentionScore(for: contact)
    }

    static func recencyAttentionScore(for contact: EchoContact) -> Int {
        let days = contact.daysSinceContact ?? 365
        return min(100, max(0, days * 2 - min(contact.reachCount, 20)))
    }
}
