import Foundation

enum DemoContactFactory {
    private struct Profile {
        let jobTitle: String
        let company: String
        let relationship: String
        let industry: String
        let businessMemory: String
    }

    private static let givenNames = [
        "Alex", "Amanda", "Andrew", "Angela", "Ben", "Brandon", "Caroline", "Chris", "Daniel", "David",
        "Diana", "Emily", "Eric", "Ethan", "Grace", "Hannah", "Henry", "Isabella", "Jack", "Jason",
        "Jennifer", "Jessica", "Kevin", "Laura", "Leo", "Linda", "Marcus", "Maria", "Mason", "Megan",
        "Nathan", "Nicole", "Olivia", "Rachel", "Robert", "Ryan", "Sophia", "Steven", "Thomas", "Victoria",
    ]

    private static let familyNames = [
        "Adams", "Allen", "Anderson", "Baker", "Brown", "Campbell", "Carter", "Chang", "Clark", "Cooper",
        "Davis", "Edwards", "Evans", "Garcia", "Green", "Hall", "Harris", "Hill", "Hughes", "Jackson",
        "Kim", "Lee", "Lewis", "Martin", "Martinez", "Miller", "Moore", "Morgan", "Nelson", "Nguyen",
        "Patel", "Perez", "Reed", "Rivera", "Roberts", "Scott", "Taylor", "Thomas", "Walker", "Wilson",
    ]

    private static let profiles: [Profile] = [
        Profile(jobTitle: "Founder", company: "Brightline Labs", relationship: "Client", industry: "Technology", businessMemory: "Exploring a seed round and a new employee benefits package."),
        Profile(jobTitle: "Product Director", company: "Atlas Mobile", relationship: "Former colleague", industry: "Software", businessMemory: "Planning a Q4 product launch and evaluating analytics vendors."),
        Profile(jobTitle: "Angel Investor", company: "Pioneer Capital", relationship: "Investor", industry: "Venture", businessMemory: "Interested in consumer AI and warm introductions to early-stage founders."),
        Profile(jobTitle: "Design Lead", company: "Canvas & Co.", relationship: "Friend", industry: "Design", businessMemory: "Building a new design system and hiring two senior designers."),
        Profile(jobTitle: "Sales VP", company: "Summit Cloud", relationship: "Prospect", industry: "SaaS", businessMemory: "Reviewing CRM workflow and sales enablement priorities this quarter."),
        Profile(jobTitle: "Attorney", company: "Oak Legal", relationship: "Advisor", industry: "Legal", businessMemory: "Supports startup contracts, privacy reviews, and international expansion."),
        Profile(jobTitle: "Physician", company: "Harbor Health", relationship: "Family friend", industry: "Healthcare", businessMemory: "Opening a second clinic and considering operations software."),
        Profile(jobTitle: "Professor", company: "Westbridge University", relationship: "Mentor", industry: "Education", businessMemory: "Leads an entrepreneurship program and connects students with mentors."),
        Profile(jobTitle: "Recruiting Partner", company: "North Talent", relationship: "Partner", industry: "Recruiting", businessMemory: "Specializes in executive searches for product and engineering leaders."),
        Profile(jobTitle: "Marketing Director", company: "Mosaic Brands", relationship: "Client", industry: "Marketing", businessMemory: "Preparing a brand refresh and reviewing agency proposals."),
        Profile(jobTitle: "Financial Advisor", company: "Evergreen Wealth", relationship: "Advisor", industry: "Finance", businessMemory: "Works with founders on liquidity planning and employee education."),
        Profile(jobTitle: "Operations Manager", company: "Fieldstone Foods", relationship: "Classmate", industry: "Retail", businessMemory: "Looking to streamline inventory reporting across six locations."),
        Profile(jobTitle: "Real Estate Broker", company: "Urban Key", relationship: "Neighbor", industry: "Real estate", businessMemory: "Expanding a commercial property portfolio and referral network."),
        Profile(jobTitle: "Consultant", company: "Meridian Strategy", relationship: "Professional network", industry: "Consulting", businessMemory: "Advises mid-market teams on growth and operating model changes."),
        Profile(jobTitle: "Engineering Manager", company: "Orbit Systems", relationship: "Former colleague", industry: "Technology", businessMemory: "Scaling the platform team and assessing developer productivity tools."),
        Profile(jobTitle: "Community Director", company: "Founders Circle", relationship: "Community", industry: "Community", businessMemory: "Organizes monthly founder dinners and partnership events."),
    ]

    private static let interactionSummaries = [
        "Quick check-in about current priorities and family updates.",
        "Shared an introduction that could help with the next project.",
        "Discussed team growth, hiring plans, and timing for follow-up.",
        "Caught up over coffee and talked through this quarter's goals.",
        "Sent a useful article and agreed to reconnect next month.",
        "Reviewed the proposal, budget range, and the next decision point.",
        "Celebrated a recent milestone and asked what support would be useful.",
        "Talked about an upcoming event and possible collaboration.",
    ]

    private static let personalMemories = [
        "Prefers a concise message before scheduling a call.",
        "Usually has more availability on Friday afternoons.",
        "Enjoys hiking and often travels with family during school breaks.",
        "Values thoughtful introductions with clear mutual relevance.",
        "Mentioned an important anniversary coming up this season.",
        "Responds best when there is a specific next step and context.",
        "Recently moved and is still discovering the neighborhood.",
        "Likes meeting in person when schedules and location allow.",
    ]

    static func identifier(for index: Int) -> String {
        "echo.demo.contact.\(index)"
    }

    static func makeContact(index: Int, now: Date = .now) -> EchoContact {
        let givenName = givenNames[index % givenNames.count]
        let familyName = familyNames[((index * 17) + (index / givenNames.count)) % familyNames.count]
        let profile = profiles[index % profiles.count]
        let daysAgo = ((index * 13) % 180) + 1
        let latestDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)
        let priority: PriorityLevel = [PriorityLevel.hot, .warm, .cold][index % 3]

        let contact = EchoContact(
            systemIdentifier: identifier(for: index),
            givenName: givenName,
            familyName: familyName,
            phoneNumber: String(format: "+1 415 555 %04d", index),
            emailAddress: "\(givenName.lowercased()).\(familyName.lowercased())\(index)@example.com",
            priority: priority,
            lastReachedOut: latestDate,
            reachCount: 2 + ((index * 5) % 24),
            companyName: profile.company,
            jobTitle: profile.jobTitle
        )
        contact.tags = [profile.relationship, profile.industry, priority.title]

        let interactionCount = 1 + (index % 6)
        for offset in 0..<interactionCount {
            let date = Calendar.current.date(
                byAdding: .day,
                value: -(daysAgo + offset * (8 + index % 9)),
                to: now
            ) ?? now
            let type = InteractionType.allCases[(index + offset) % InteractionType.allCases.count]
            let summary = interactionSummaries[(index * 3 + offset) % interactionSummaries.count]
            contact.interactions.append(Interaction(date: date, type: type, summary: summary, contact: contact))
        }

        contact.notes.append(EchoNote(
            createdAt: latestDate ?? now,
            content: personalMemories[index % personalMemories.count],
            contact: contact
        ))
        contact.notes.append(EchoNote(
            createdAt: Calendar.current.date(byAdding: .day, value: -(daysAgo + 3), to: now) ?? now,
            content: profile.businessMemory,
            contact: contact
        ))

        return contact
    }

    static func makeDeal(index: Int, contact: EchoContact, now: Date = .now) -> Deal? {
        guard index.isMultiple(of: 4) else { return nil }
        let stages: [DealStage] = [.lead, .contacted, .quoted, .negotiating, .closedWon, .closedLost]
        let titles = [
            "Advisory engagement", "Team benefits review", "Growth workshop", "Platform rollout",
            "Executive search", "Partnership program", "Strategy sprint", "Annual planning",
        ]
        let nextAction = Calendar.current.date(byAdding: .day, value: 2 + (index % 28), to: now)
        return Deal(
            title: titles[(index / 4) % titles.count],
            value: Double(4_000 + ((index * 1_375) % 46_000)),
            stage: stages[(index / 4) % stages.count],
            nextActionDate: nextAction,
            contact: contact
        )
    }
}
