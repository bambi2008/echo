import SwiftUI
import StoreKit

struct RatingManager {
    static let threshold = 10
    static func shouldPrompt() -> Bool {
        let count = StreakManager.totalReachCount
        let lastPrompted = UserDefaults.standard.integer(forKey: "echo_last_rating_prompt_count")
        return count >= threshold && count != lastPrompted
    }
    static func promptIfNeeded() {
        guard shouldPrompt() else { return }
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
            UserDefaults.standard.set(StreakManager.totalReachCount, forKey: "echo_last_rating_prompt_count")
        }
    }
}

struct FreeTierLimits {
    static let maxEchoLayerContacts = 15
    static let maxHistoryDays = 30
    static let maxNotesPerContact = 5
}

struct AhaMomentHelper {
    static func findMostOverdue(contacts: [EchoContact]) -> EchoContact? {
        guard !contacts.isEmpty else { return nil }
        return contacts.min { a, b in
            let aDate = a.lastReachedOut ?? .distantPast
            let bDate = b.lastReachedOut ?? .distantPast
            return aDate < bDate
        }
    }
    static func ahaMessage(for contact: EchoContact) -> String {
        let days: Int
        if let last = contact.lastReachedOut {
            days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        } else {
            return "👋 Say hi to \(contact.givenName) — they're new to your Echo Layer!"
        }
        if days >= 14 { return "👋 \(contact.givenName) needs you — it's been \(days) days!" }
        else if days >= 7 { return "👋 It's been \(days) days since you talked to \(contact.givenName)." }
        else { return "👋 Say hi to \(contact.givenName)!" }
    }
}
