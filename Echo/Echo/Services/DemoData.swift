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

    /// Removes contacts shipped only for the early product demo. This is
    /// intentionally idempotent so upgraded installs are cleaned as well as
    /// fresh installs, without touching user-created or imported contacts.
    static func removeLegacyDemoContacts(in context: ModelContext) {
        let contacts = (try? context.fetch(FetchDescriptor<EchoContact>())) ?? []
        let demoContacts = contacts.filter(isLegacyDemoContact)
        guard !demoContacts.isEmpty else { return }

        let identifiers = Set(demoContacts.map(\.systemIdentifier))
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        for deal in deals where deal.contact.map({ identifiers.contains($0.systemIdentifier) }) == true {
            context.delete(deal)
        }
        demoContacts.forEach(context.delete)
        try? context.save()
    }

    private static func isLegacyDemoContact(_ contact: EchoContact) -> Bool {
        if contact.systemIdentifier.hasPrefix("echo.demo.contact.") { return true }
        if contact.emailAddress?.lowercased().hasSuffix("@example.com") == true { return true }

        let curatedSignatures: Set<String> = [
            "Sarah|Chen|Northstar Studio",
            "Mike|Johnson|Harbor Financial",
            "Lisa|Park|",
        ]
        let signature = "\(contact.givenName)|\(contact.familyName)|\(contact.companyName ?? "")"
        guard curatedSignatures.contains(signature) else { return false }
        let demoPhrases = [
            "Her mom is recovering well",
            "Discussed a job change",
            "Monthly coaching session",
        ]
        return contact.notes.contains { note in
            demoPhrases.contains { note.content.contains($0) }
        }
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
