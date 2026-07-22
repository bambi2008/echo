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
        contact.lastReachedOut = .now
        contact.reachCount += 1
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contact.notes.append(EchoNote(content: note, contact: contact))
        }
        try? context.save()
    }

    static func attentionScore(for contact: EchoContact) -> Int {
        let days = contact.daysSinceContact ?? 365
        return min(100, max(0, days * 2 - min(contact.reachCount, 20)))
    }
}
