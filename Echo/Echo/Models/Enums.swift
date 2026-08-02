import Foundation

enum InteractionType: String, Codable, CaseIterable {
    case reachedOut = "reached_out"
    case called = "called"
    case messaged = "messaged"
    case emailed = "emailed"
    case metInPerson = "met_in_person"
    var icon: String {
        switch self {
        case .reachedOut: return "hand.wave"
        case .called: return "phone"
        case .messaged: return "message"
        case .emailed: return "envelope"
        case .metInPerson: return "person.2"
        }
    }
    var label: String {
        switch self {
        case .reachedOut: return "Reached out"
        case .called: return "Called"
        case .messaged: return "Messaged"
        case .emailed: return "Emailed"
        case .metInPerson: return "Met in person"
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable {
    case hot = "hot"
    case warm = "warm"
    case cold = "cold"
    var color: String {
        switch self {
        case .hot: return "#FF453A"
        case .warm: return "#F59E0B"
        case .cold: return "#636366"
        }
    }
    var label: String {
        switch self {
        case .hot: return "Hot"
        case .warm: return "Warm"
        case .cold: return "Cold"
        }
    }
}

enum DealStage: String, Codable, CaseIterable {
    case lead = "lead"
    case contacted = "contacted"
    case quoted = "quoted"
    case negotiating = "negotiating"
    case closedWon = "closed_won"
    case closedLost = "closed_lost"
    var kanbanIndex: Int {
        switch self {
        case .lead: return 0
        case .contacted: return 1
        case .quoted: return 2
        case .negotiating: return 3
        case .closedWon: return 4
        case .closedLost: return 5
        }
    }
    var label: String {
        switch self {
        case .lead: return "Lead"
        case .contacted: return "Contacted"
        case .quoted: return "Quoted"
        case .negotiating: return "Negotiating"
        case .closedWon: return "Closed Won"
        case .closedLost: return "Closed Lost"
        }
    }
    var color: String {
        switch self {
        case .lead: return "#636366"
        case .contacted: return "#3B82F6"
        case .quoted: return "#F59E0B"
        case .negotiating: return "#FF453A"
        case .closedWon: return "#34C759"
        case .closedLost: return "#8E8E93"
        }
    }
}
