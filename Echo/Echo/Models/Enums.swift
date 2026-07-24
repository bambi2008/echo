import Foundation

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
