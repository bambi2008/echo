import Foundation

/// A model identifier deliberately has no fixed enum cases. New DeepSeek model IDs
/// can be used immediately without changing or recompiling this package.
public struct AIModelID: RawRepresentable, Codable, Hashable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public var description: String { rawValue }
}

public enum AITask: String, Codable, CaseIterable, Sendable {
    case generalChat = "general_chat"
    case conversationOpener = "conversation_opener"
    case relationshipInsight = "relationship_insight"
    case relationshipHealth = "relationship_health"
    case businessCardOCR = "business_card_ocr"
    case policyOCR = "policy_ocr"
    case salesCoach = "sales_coach"
    case dailyBriefing = "daily_briefing"
}

public struct AIModelPolicy: Codable, Equatable, Sendable {
    public var primary: AIModelID
    public var fallbacks: [AIModelID]
    public var temperature: Double
    public var maxOutputTokens: Int

    public init(
        primary: AIModelID,
        fallbacks: [AIModelID] = [],
        temperature: Double = 0.7,
        maxOutputTokens: Int = 800
    ) {
        self.primary = primary
        self.fallbacks = fallbacks
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }

    public var candidates: [AIModelID] {
        var seen = Set<AIModelID>()
        return ([primary] + fallbacks).filter { !$0.rawValue.isEmpty && seen.insert($0).inserted }
    }
}

public struct AIModelConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var updatedAt: Date
    public var policies: [AITask: AIModelPolicy]

    public init(
        schemaVersion: Int = 1,
        updatedAt: Date = .now,
        policies: [AITask: AIModelPolicy]
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.policies = policies
    }

    /// Defaults avoid the DeepSeek model aliases scheduled for retirement on
    /// 2026-07-24. Every value remains replaceable at runtime.
    public static let deepSeekV4 = AIModelConfiguration(policies: [
        .generalChat: .init(primary: "deepseek-v4-flash", fallbacks: ["deepseek-v4-pro"]),
        .conversationOpener: .init(primary: "deepseek-v4-flash", fallbacks: ["deepseek-v4-pro"], maxOutputTokens: 200),
        .relationshipInsight: .init(primary: "deepseek-v4-flash", fallbacks: ["deepseek-v4-pro"]),
        .relationshipHealth: .init(primary: "deepseek-v4-pro", fallbacks: ["deepseek-v4-flash"]),
        .businessCardOCR: .init(primary: "deepseek-v4-pro", fallbacks: ["deepseek-v4-flash"], temperature: 0, maxOutputTokens: 1_000),
        .policyOCR: .init(primary: "deepseek-v4-pro", fallbacks: ["deepseek-v4-flash"], temperature: 0, maxOutputTokens: 1_500),
        .salesCoach: .init(primary: "deepseek-v4-pro", fallbacks: ["deepseek-v4-flash"], temperature: 0.4, maxOutputTokens: 1_200),
        .dailyBriefing: .init(primary: "deepseek-v4-flash", fallbacks: ["deepseek-v4-pro"], temperature: 0.5, maxOutputTokens: 1_000),
    ])
}

public struct AIUsage: Codable, Equatable, Sendable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    public init(promptTokens: Int?, completionTokens: Int?, totalTokens: Int?) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public struct AIResult: Equatable, Sendable {
    public let text: String
    public let model: AIModelID
    public let usage: AIUsage?

    public init(text: String, model: AIModelID, usage: AIUsage? = nil) {
        self.text = text
        self.model = model
        self.usage = usage
    }
}
