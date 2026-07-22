import Foundation
import SwiftData

@MainActor
enum DemoData {
    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<EchoContact>()
        descriptor.fetchLimit = 1
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        let calendar = Calendar.current
        let sarah = EchoContact(
            givenName: "Sarah",
            familyName: "Chen",
            priority: .warm,
            lastReachedOut: calendar.date(byAdding: .day, value: -19, to: .now),
            reachCount: 8,
            companyName: "Northstar Studio",
            jobTitle: "Founder"
        )
        sarah.notes.append(EchoNote(content: "Her mom is recovering well. Check in this week.", contact: sarah))

        let mike = EchoContact(
            givenName: "Mike",
            familyName: "Johnson",
            priority: .hot,
            lastReachedOut: calendar.date(byAdding: .day, value: -7, to: .now),
            reachCount: 14,
            companyName: "Harbor Financial",
            jobTitle: "Advisor"
        )
        mike.notes.append(EchoNote(content: "Discussed a job change and education planning.", contact: mike))

        let lisa = EchoContact(
            givenName: "Lisa",
            familyName: "Park",
            priority: .cold,
            lastReachedOut: calendar.date(byAdding: .day, value: -35, to: .now),
            reachCount: 5,
            jobTitle: "Mentor"
        )
        lisa.notes.append(EchoNote(content: "Monthly coaching session; ask about her upcoming talk.", contact: lisa))

        [sarah, mike, lisa].forEach(context.insert)
        context.insert(Deal(title: "Family protection review", value: 12_000, stage: .quoted, nextActionDate: .now, contact: mike))
        context.insert(Deal(title: "Founder benefits plan", value: 8_500, stage: .contacted, contact: sarah))
        try? context.save()
    }
}
