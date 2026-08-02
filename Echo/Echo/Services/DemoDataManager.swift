import Foundation
import SwiftData
struct DemoDataManager {
    static func loadDemoData(context: ModelContext) {
        let desc = FetchDescriptor<EchoContact>(); let existing = (try? context.fetch(desc)) ?? []; if !existing.isEmpty { return }
        let now = Date()
        let data: [(String, String, String, String, Double)] = [("Sarah", "Chen", "Apple", "Designer", -2), ("Marcus", "Johnson", "Google", "PM", -45), ("Yuki", "Tanaka", "Sony", "Director", -8), ("Emma", "Williams", "Spotify", "Data Scientist", -15), ("Alex", "Rodriguez", "Tesla", "Engineer", -62), ("Priya", "Patel", "Microsoft", "Researcher", -5), ("James", "Wilson", "Adobe", "Design Lead", -28), ("Sophia", "Mueller", "BMW", "Manager", -3), ("David", "Kim", "Samsung", "VP", -90), ("Olivia", "Garcia", "Netflix", "Strategist", -12), ("Liam", "OBrien", "Stripe", "Founder", -40), ("Zara", "Hassan", "Figma", "Researcher", -6)]
        for (i, d) in data.enumerated() {
            let c = EchoContact(systemIdentifier: "demo_\(i)", givenName: d.0, familyName: d.1, phoneNumber: "+1415555\(String(format: "%03d", i))", emailAddress: "\(d.0.lowercased())@example.com")
            c.companyName = d.2; c.jobTitle = d.3; c.isInEchoLayer = true; c.lastReachedOut = now.addingTimeInterval(86400 * d.4); c.reachCount = Int.random(in: 1...12)
            context.insert(c)
            let i1 = Interaction(type: .messaged, note: "Nice catching up!"); i1.date = c.lastReachedOut ?? now; i1.contact = c; context.insert(i1)
            let gap = abs(d.4)
            if gap > 10 { let i2 = Interaction(type: .called, note: "Quick call."); i2.date = (c.lastReachedOut ?? now).addingTimeInterval(-86400 * 14); i2.contact = c; context.insert(i2) }
            if gap > 30 { let i3 = Interaction(type: .metInPerson, note: "Coffee together."); i3.date = (c.lastReachedOut ?? now).addingTimeInterval(-86400 * 30); i3.contact = c; context.insert(i3) }
            if let fetched = try? context.fetch(FetchDescriptor<Interaction>()) { c.interactions = fetched.filter { $0.contact?.systemIdentifier == c.systemIdentifier } }
        }
        try? context.save()
    }
}