import Foundation

struct StreakManager {
    static let defaults = UserDefaults.standard
    static var currentStreak: Int { defaults.integer(forKey: "echo_weekly_streak") }
    static func recordReach() {
        let calendar = Calendar.current
        let thisWeek = calendar.component(.weekOfYear, from: Date())
        let lastWeek = defaults.integer(forKey: "echo_last_reach_week")
        if lastWeek == 0 { defaults.set(1, forKey: "echo_weekly_streak") }
        else if thisWeek == lastWeek { return }
        else if thisWeek == lastWeek + 1 { defaults.set(currentStreak + 1, forKey: "echo_weekly_streak") }
        else { defaults.set(1, forKey: "echo_weekly_streak") }
        defaults.set(thisWeek, forKey: "echo_last_reach_week")
    }
    static var streakEmoji: String {
        switch currentStreak {
        case 0..<2: return "🌱"
        case 2..<5: return "🔥"
        case 5..<12: return "⭐"
        case 12..<24: return "💎"
        default: return "👑"
        }
    }
    static var totalReachCount: Int { defaults.integer(forKey: "echo_total_reach") }
    static func incrementTotalReach() { defaults.set(totalReachCount + 1, forKey: "echo_total_reach") }
}
