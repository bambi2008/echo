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

    /// Each reflection question has a different decision boundary. Keeping
    /// the same four answers for every question made “protect” and
    /// “boundaries” feel interchangeable, even though they ask for opposite
    /// decisions.
    var intentChoices: [RelationshipIntent] {
        switch self {
        case .protect: [.deepen, .maintain, .light]
        case .reconnect: [.deepen, .maintain, .light]
        case .lighten: [.light, .maintain, .deepen]
        case .boundaries: [.pause, .light, .maintain]
        case .ongoing: RelationshipIntent.allCases
        }
    }

    func intentGuidance(for intent: RelationshipIntent) -> String {
        switch (self, intent) {
        case (.protect, .deepen): "Make more room for this person."
        case (.protect, .maintain): "Keep the relationship in your regular rhythm."
        case (.protect, .light): "Keep a warm connection without adding pressure."
        case (.reconnect, .deepen): "Choose a small step toward a more active connection."
        case (.reconnect, .maintain): "Reconnect gently, then let the rhythm settle."
        case (.reconnect, .light): "Reach out lightly without forcing a reset."
        case (.lighten, .light): "Let this stay easy and low-pressure."
        case (.lighten, .maintain): "Keep the connection steady without over-investing."
        case (.lighten, .deepen): "This relationship may deserve more attention than you expected."
        case (.boundaries, .pause): "Give yourself clear space for now."
        case (.boundaries, .light): "Keep contact limited and intentional."
        case (.boundaries, .maintain): "Keep the boundary while preserving a steady connection."
        default: "Choose the direction that feels most honest today."
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
    case discovered, qualified, contacted, engaged, interested, opportunity, humanAttention, won, lost
    // Kept readable for existing stores and callers. New pipelines do not use these by default.
    case lead, quoted, negotiating, closedWon, closedLost
    var id: String { rawValue }
    var title: String {
        switch self {
        case .discovered: "Discovered"
        case .qualified: "Qualified"
        case .contacted: "Contacted"
        case .engaged: "Engaged"
        case .interested: "Interested"
        case .opportunity: "Opportunity"
        case .humanAttention: "Human Attention"
        case .won: "Won"
        case .lost: "Lost"
        case .lead: "Lead"
        case .quoted: "Quoted"
        case .negotiating: "Negotiating"
        case .closedWon: "Won"
        case .closedLost: "Lost"
        }
    }
    var symbol: String {
        switch self {
        case .discovered, .lead: "sparkle.magnifyingglass"
        case .qualified: "checkmark.circle.fill"
        case .contacted: "message.fill"
        case .engaged: "person.2.fill"
        case .interested: "hand.thumbsup.fill"
        case .opportunity: "scope"
        case .humanAttention: "person.crop.circle.badge.exclamationmark"
        case .won: "checkmark.seal.fill"
        case .lost: "xmark.circle.fill"
        case .quoted: "doc.text.fill"
        case .negotiating: "arrow.left.arrow.right"
        case .closedWon: "checkmark.seal.fill"
        case .closedLost: "xmark.circle.fill"
        }
    }

    static let defaultAgenticStages: [DealStage] = [
        .discovered, .qualified, .contacted, .engaged, .interested,
        .opportunity, .humanAttention, .won, .lost,
    ]

    var isClosed: Bool {
        [.won, .lost, .closedWon, .closedLost].contains(self)
    }
}

enum AgentAutonomyLevel: String, Codable, CaseIterable, Identifiable {
    case manual, assist, supervised, autonomous
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var explanation: String {
        switch self {
        case .manual: "No agent actions"
        case .assist: "Analyze and recommend"
        case .supervised: "Prepare actions for approval"
        case .autonomous: "Act only within an explicit policy"
        }
    }
}

enum PipelineItemStatus: String, Codable, CaseIterable, Identifiable {
    case active, paused, won, lost, archived
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum WorkPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rank: Int {
        switch self { case .low: 0; case .medium: 1; case .high: 2; case .urgent: 3 }
    }
}

enum InteractionActor: String, Codable, CaseIterable, Identifiable {
    case human, agent, external
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum InteractionDirection: String, Codable, CaseIterable, Identifiable {
    case inbound, outbound, internalDirection = "internal"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AgentActionType: String, Codable, CaseIterable, Identifiable {
    case research, analysis, recommendation, outreach, followUp, messageReceived
    case stageChange, scoreChange, escalation, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .followUp: "Follow up"
        case .messageReceived: "Message received"
        case .stageChange: "Stage change"
        case .scoreChange: "Score change"
        default: rawValue.capitalized
        }
    }
}

enum AgentActionStatus: String, Codable, CaseIterable, Identifiable {
    case proposed, approved, running, completed, failed, cancelled
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum EvidenceSourceType: String, Codable, CaseIterable, Identifiable {
    case web, document, email, userProvided, system, other
    var id: String { rawValue }
    var title: String {
        switch self { case .userProvided: "User provided"; default: rawValue.capitalized }
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
