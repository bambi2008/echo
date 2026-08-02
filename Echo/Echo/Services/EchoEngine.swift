import Foundation
import SwiftData

final class EchoEngine {
    static func sortedEchoLayer(from contacts: [EchoContact]) -> [EchoContact] {
        contacts.filter { $0.isInEchoLayer }.sorted { a, b in
            let aDate = a.lastReachedOut ?? .distantPast
            let bDate = b.lastReachedOut ?? .distantPast
            return aDate < bDate
        }
    }
    static func gapDescription(for contact: EchoContact) -> String {
        guard let last = contact.lastReachedOut else { return "Never reached out" }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        switch days {
        case 0: return "Reached out today"
        case 1: return "1 day ago"
        case 2...6: return "\(days) days ago"
        case 7...13: return "1 week ago"
        case 14...29: return "\(days) days ago"
        case 30...59: return "1 month ago"
        default: return "\(days / 30) months ago"
        }
    }
    static func isOverdue(_ contact: EchoContact) -> Bool {
        guard let last = contact.lastReachedOut else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days >= 14
    }
    static func recordReach(on contact: EchoContact, type: InteractionType, note: String = "", context: ModelContext) {
        let interaction = Interaction(type: type, note: note)
        interaction.contact = contact
        contact.interactions.append(interaction)
        contact.lastReachedOut = Date()
        contact.reachCount += 1
        context.insert(interaction)
        try? context.save()
    }
}
