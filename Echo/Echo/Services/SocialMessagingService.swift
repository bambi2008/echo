import Foundation

enum SocialMessagingService {
    struct Destination {
        let url: URL
        let draftWasIncluded: Bool
    }

    static func destination(
        for platform: SocialPlatform,
        identifier rawIdentifier: String,
        draft: String
    ) -> Destination? {
        let identifier = normalizedIdentifier(rawIdentifier, for: platform)
        guard !identifier.isEmpty else { return nil }

        switch platform {
        case .whatsapp:
            let digits = identifier.filter(\.isNumber)
            guard !digits.isEmpty else { return nil }
            return destination(
                base: "https://wa.me/\(digits)",
                query: [URLQueryItem(name: "text", value: draft)],
                draftWasIncluded: true
            )
        case .telegram:
            return destination(
                base: "https://t.me/\(identifier)",
                query: [URLQueryItem(name: "text", value: draft)],
                draftWasIncluded: true
            )
        case .reddit:
            return destination(
                base: "https://www.reddit.com/message/compose/",
                query: [
                    URLQueryItem(name: "to", value: identifier),
                    URLQueryItem(name: "message", value: draft),
                ],
                draftWasIncluded: true
            )
        case .facebook:
            return URL(string: "https://m.me/\(identifier)").map { Destination(url: $0, draftWasIncluded: false) }
        case .instagram:
            return URL(string: "https://www.instagram.com/\(identifier)/").map { Destination(url: $0, draftWasIncluded: false) }
        case .x:
            return URL(string: "https://x.com/\(identifier)").map { Destination(url: $0, draftWasIncluded: false) }
        case .linkedin:
            return URL(string: "https://www.linkedin.com/in/\(identifier)").map { Destination(url: $0, draftWasIncluded: false) }
        case .discord:
            let base = identifier.allSatisfy(\.isNumber)
                ? "https://discord.com/users/\(identifier)"
                : "https://discord.com/channels/@me"
            return URL(string: base).map { Destination(url: $0, draftWasIncluded: false) }
        }
    }

    static func normalizedIdentifier(_ value: String, for platform: SocialPlatform) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if platform == .whatsapp { return result }
        result = result.replacingOccurrences(of: "@", with: "")
        if let url = URL(string: result), url.scheme != nil {
            let parts = url.pathComponents.filter { $0 != "/" }
            if platform == .linkedin,
               let marker = parts.firstIndex(of: "in"),
               parts.indices.contains(marker + 1) {
                return parts[marker + 1]
            }
            if let last = parts.last { return last }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func destination(
        base: String,
        query: [URLQueryItem],
        draftWasIncluded: Bool
    ) -> Destination? {
        guard var components = URLComponents(string: base) else { return nil }
        components.queryItems = query
        return components.url.map { Destination(url: $0, draftWasIncluded: draftWasIncluded) }
    }
}
