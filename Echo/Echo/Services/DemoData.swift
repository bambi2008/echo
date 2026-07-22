import Foundation
import SwiftData

@MainActor
enum DemoData {
    static let targetContactCount = 200

    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<EchoContact>()
        var contacts = (try? context.fetch(descriptor)) ?? []

        if contacts.isEmpty {
            let curated = curatedContacts()
            curated.forEach(context.insert)
            contacts.append(contentsOf: curated)

            if let mike = curated.first(where: { $0.givenName == "Mike" }) {
                context.insert(Deal(title: "Family protection review", value: 12_000, stage: .quoted, nextActionDate: .now, contact: mike))
            }
            if let sarah = curated.first(where: { $0.givenName == "Sarah" }) {
                context.insert(Deal(title: "Founder benefits plan", value: 8_500, stage: .contacted, contact: sarah))
            }
        }

        var identifiers = Set(contacts.map(\.systemIdentifier))
        var index = 0

        while contacts.count < targetContactCount {
            let identifier = DemoContactFactory.identifier(for: index)
            defer { index += 1 }
            guard !identifiers.contains(identifier) else { continue }

            let contact = DemoContactFactory.makeContact(index: index)
            context.insert(contact)
            contacts.append(contact)
            identifiers.insert(identifier)

            if let deal = DemoContactFactory.makeDeal(index: index, contact: contact) {
                context.insert(deal)
            }
        }

        try? context.save()
    }

    private static func curatedContacts() -> [EchoContact] {
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
        sarah.tags = ["Founder", "Client", "Design"]
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
        mike.tags = ["Advisor", "Client", "Finance"]
        mike.notes.append(EchoNote(content: "Discussed a job change and education planning.", contact: mike))

        let lisa = EchoContact(
            givenName: "Lisa",
            familyName: "Park",
            priority: .cold,
            lastReachedOut: calendar.date(byAdding: .day, value: -35, to: .now),
            reachCount: 5,
            jobTitle: "Mentor"
        )
        lisa.tags = ["Mentor", "Friend"]
        lisa.notes.append(EchoNote(content: "Monthly coaching session; ask about her upcoming talk.", contact: lisa))

        return [sarah, mike, lisa]
    }
}
