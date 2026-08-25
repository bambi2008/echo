import Foundation

enum RelationshipIntent: String, Codable, CaseIterable, Identifiable {
    case deepen
    case maintain
    case light
    case pause

    var id: String { rawValue }
    var title: String {
        switch self {
        case .deepen: String(localized: "Grow closer")
        case .maintain: String(localized: "Keep steady")
        case .light: String(localized: "Keep it light")
        case .pause: String(localized: "Give it space")
        }
    }
    var symbol: String {
        switch self {
        case .deepen: "arrow.up.right.circle.fill"
        case .maintain: "equal.circle.fill"
        case .light: "leaf.circle.fill"
        case .pause: "pause.circle.fill"
        }
    }
}

enum ReflectionTheme: String, Codable, CaseIterable, Identifiable {
    case protect
    case reconnect
    case lighten
    case boundaries
    case ongoing

    var id: String { rawValue }
    var title: String {
        switch self {
        case .protect: String(localized: "People you want to keep in view")
        case .reconnect: String(localized: "People you want to reconnect with")
        case .lighten: String(localized: "Relationships that can stay light")
        case .boundaries: String(localized: "Relationships that need clearer space")
        case .ongoing: String(localized: "A moment to reflect")
        }
    }
    var question: String {
        switch self {
        case .protect: String(localized: "Who are the people you do not want to slowly disappear from your life?")
        case .reconnect: String(localized: "Who have you been meaning to reconnect with or know more deeply?")
        case .lighten: String(localized: "Who can remain in your life without needing frequent attention?")
        case .boundaries: String(localized: "Which relationships need a little more distance or a clearer boundary?")
        case .ongoing: String(localized: "Who has unexpectedly come to mind lately?")
        }
    }
}

enum RelationshipActionType: String, Codable, CaseIterable, Identifiable {
    case message
    case call
    case meet
    case remember
    case none

    var id: String { rawValue }
    var title: String {
        switch self {
        case .message: String(localized: "Send a message")
        case .call: String(localized: "Make a call")
        case .meet: String(localized: "Plan to meet")
        case .remember: String(localized: "Write down something to say")
        case .none: String(localized: "No action this week")
        }
    }
    var symbol: String {
        switch self {
        case .message: "message.fill"
        case .call: "phone.fill"
        case .meet: "person.2.fill"
        case .remember: "note.text"
        case .none: "moon.zzz.fill"
        }
    }
}

enum RelationshipActionStatus: String, Codable {
    case planned
    case completed
    case skipped

    var localizedTitle: String {
        switch self {
        case .planned: String(localized: "Planned")
        case .completed: String(localized: "Completed")
        case .skipped: String(localized: "Let go")
        }
    }
}

enum ReflectionOutcome: String, Codable, CaseIterable, Identifiable {
    case closer
    case steady
    case unchanged
    case moreDistance
    case unsure

    var id: String { rawValue }
    var title: String {
        switch self {
        case .closer: String(localized: "I want to grow closer")
        case .steady: String(localized: "It feels right as it is")
        case .unchanged: String(localized: "Not much has changed")
        case .moreDistance: String(localized: "I want a little more distance")
        case .unsure: String(localized: "Not sure yet")
        }
    }
}

enum OnboardingStage: String, Codable {
    case philosophy
    case coreQuestion
    case contactSelection
    case intentions
    case context
    case action
    case completed
}

enum PriorityLevel: String, Codable, CaseIterable, Identifiable {
    case hot, warm, cold
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .hot: "flame.fill"
        case .warm: "sun.max.fill"
        case .cold: "snowflake"
        }
    }
}

enum RelationshipDomain: String, Codable, CaseIterable, Identifiable {
    case personal
    case business
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Personal"
        case .business: "Business"
        case .both: "Both"
        }
    }

    var symbol: String {
        switch self {
        case .personal: "heart.fill"
        case .business: "briefcase.fill"
        case .both: "person.crop.circle.badge.checkmark"
        }
    }

    func includes(_ domain: RelationshipDomain) -> Bool {
        self == .both || self == domain
    }
}

enum ContactIdentity: String, CaseIterable, Identifiable {
    case client = "Client"
    case prospect = "Prospect"
    case partner = "Partner"
    case investor = "Investor"
    case advisor = "Advisor"
    case professionalNetwork = "Professional network"
    case colleague = "Former colleague"
    case mentor = "Mentor"
    case friend = "Friend"
    case family = "Family friend"
    case classmate = "Classmate"
    case neighbor = "Neighbor"
    case community = "Community"

    var id: String { rawValue }

    var domain: RelationshipDomain {
        switch self {
        case .client, .prospect, .partner, .investor, .advisor, .professionalNetwork:
            .business
        case .colleague, .mentor, .friend, .family, .classmate, .neighbor, .community:
            .personal
        }
    }

    var symbol: String {
        switch self {
        case .client: "person.crop.circle.badge.checkmark"
        case .prospect: "scope"
        case .partner: "person.2.fill"
        case .investor: "chart.line.uptrend.xyaxis"
        case .advisor: "lightbulb.fill"
        case .professionalNetwork: "network"
        case .colleague: "briefcase.fill"
        case .mentor: "graduationcap.fill"
        case .friend: "heart.fill"
        case .family: "house.fill"
        case .classmate: "books.vertical.fill"
        case .neighbor: "building.2.fill"
        case .community: "person.3.fill"
        }
    }
}

enum DealStage: String, Codable, CaseIterable, Identifiable {
    case lead, contacted, quoted, negotiating, closedWon, closedLost
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lead: "Lead"
        case .contacted: "Contacted"
        case .quoted: "Quoted"
        case .negotiating: "Negotiating"
        case .closedWon: "Won"
        case .closedLost: "Lost"
        }
    }
    var symbol: String {
        switch self {
        case .lead: "sparkle.magnifyingglass"
        case .contacted: "message.fill"
        case .quoted: "doc.text.fill"
        case .negotiating: "arrow.left.arrow.right"
        case .closedWon: "checkmark.seal.fill"
        case .closedLost: "xmark.circle.fill"
        }
    }
}

enum InteractionType: String, Codable, CaseIterable, Identifiable {
    case reachedOut, called, messaged, emailed, metInPerson
    var id: String { rawValue }
    var title: String {
        switch self {
        case .reachedOut: "Reached out"
        case .called: "Called"
        case .messaged: "Messaged"
        case .emailed: "Emailed"
        case .metInPerson: "Met in person"
        }
    }
    var symbol: String {
        switch self {
        case .reachedOut: "hand.wave.fill"
        case .called: "phone.fill"
        case .messaged: "message.fill"
        case .emailed: "envelope.fill"
        case .metInPerson: "person.2.fill"
        }
    }
}
