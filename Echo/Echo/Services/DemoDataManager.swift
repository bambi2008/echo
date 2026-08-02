import Foundation
import SwiftData
struct DemoDataManager {
    static func loadDemoData(context: ModelContext) {
        let desc = FetchDescriptor<EchoContact>(); let existing = (try? context.fetch(desc)) ?? []; if !existing.isEmpty { return }
        let now = Date()
        let data: [(String, String, String, String, Double)] = [("Sarah", "Chen", "Apple", "Designer", -2), ("Marcus", "Johnson", "Google", "PM", -45), ("Yuki", "Tanaka", "Sony", "Director", -8), ("Emma", "Williams", "Spotify", "Data Scientist", -15), ("Alex", "Rodriguez", "Tesla", "Engineer", -62), ("Priya", "Patel", "Microsoft", "Researcher", -5), ("James", "Wilson", "Adobe", "Design Lead", -28), ("Sophia", "Mueller", "BMW", "Manager", -3), ("David", "Kim", "Samsung", "VP", -90), ("Olivia", "Garcia", "Netflix", "Strategist", -12), ("Liam", "OBrien", "Stripe", "Founder", -40), ("Zara", "Hassan", "Figma", "Researcher", -6)]
        for d in data {
            let c = EchoContact(givenName: d.0, familyName: d.1, organizationName: d.2, jobTitle: d.3, phoneNumbers: ["+1415555111"], emailAddresses: ["\(d.0.lowercased())@example.com"], isInEchoLayer: true, lastReachedOut: now.addingTimeInterval(86400 * d.4), priority: 0)
            context.insert(c)
            let gap = abs(d.4) * 86400
            var inter: [Interaction] = [Interaction(contactID: c.id, type: .messaged, date: c.lastReachedOut ?? now, notes: "Nice catching up!", sentiment: 0.7)]
            if gap > 86400 * 10 { inter.append(Interaction(contactID: c.id, type: .called, date: (c.lastReachedOut ?? now).addingTimeInterval(-86400 * 14), notes: "Quick call.", sentiment: 0.5)) }
            if gap > 86400 * 30 { inter.append(Interaction(contactID: c.id, type: .met, date: (c.lastReachedOut ?? now).addingTimeInterval(-86400 * 30), notes: "Coffee together.", sentiment: 0.9)) }
            for i in inter { context.insert(i) }; c.interactions = inter
        }
        try? context.save()
    }
}