import Foundation

/// Contains operational metadata only. Prompts, responses, identifiers, API
/// keys, and provider error messages are deliberately excluded.
public struct AIServiceEvent: Sendable, Equatable {
    public let task: AITask
    public let requestedModel: AIModelID
    public let actualModel: AIModelID?
    public let attempt: Int
    public let usedFallback: Bool
    public let durationMilliseconds: Int
    public let outcome: AIServiceOutcome
    public let usage: AIUsage?

    public init(
        task: AITask,
        requestedModel: AIModelID,
        actualModel: AIModelID?,
        attempt: Int,
        usedFallback: Bool,
        durationMilliseconds: Int,
        outcome: AIServiceOutcome,
        usage: AIUsage?
    ) {
        self.task = task
        self.requestedModel = requestedModel
        self.actualModel = actualModel
        self.attempt = attempt
        self.usedFallback = usedFallback
        self.durationMilliseconds = durationMilliseconds
        self.outcome = outcome
        self.usage = usage
    }
}

public enum AIServiceOutcome: String, Codable, Sendable {
    case success
    case authenticationFailure
    case rateLimited
    case modelUnavailable
    case providerFailure
    case transportFailure
    case invalidResponse
    case configurationFailure
    case unknownFailure
}

public protocol AIServiceObserver: Sendable {
    func record(_ event: AIServiceEvent) async
}

public struct NoOpAIServiceObserver: AIServiceObserver {
    public init() {}
    public func record(_ event: AIServiceEvent) async {}
}
