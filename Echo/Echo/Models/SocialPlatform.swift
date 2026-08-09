import Foundation

enum SocialPlatform: String, CaseIterable, Identifiable, Codable {
    case whatsapp
    case telegram
    case instagram
    case facebook
    case x
    case linkedin
    case reddit
    case discord

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whatsapp: "WhatsApp"
        case .telegram: "Telegram"
        case .instagram: "Instagram"
        case .facebook: "Facebook"
        case .x: "X"
        case .linkedin: "LinkedIn"
        case .reddit: "Reddit"
        case .discord: "Discord"
        }
    }

    var symbol: String {
        switch self {
        case .whatsapp: "phone.bubble.fill"
        case .telegram: "paperplane.fill"
        case .instagram: "camera.fill"
        case .facebook: "person.2.fill"
        case .x: "at"
        case .linkedin: "briefcase.fill"
        case .reddit: "bubble.left.and.bubble.right.fill"
        case .discord: "headphones"
        }
    }

    var fieldPrompt: String {
        switch self {
        case .whatsapp: "Phone number with country code"
        case .discord: "Username or numeric user ID"
        case .linkedin: "Profile name or URL"
        default: "Username or profile URL"
        }
    }
}
