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
