import Foundation

public final class AIService: Sendable {
    private let client: any AIProviderClient
    private let observer: any AIServiceObserver
    public let router: AIModelRouter

    public init(
        client: any AIProviderClient,
        router: AIModelRouter = AIModelRouter(),
        observer: any AIServiceObserver = NoOpAIServiceObserver()
    ) {
        self.client = client
        self.router = router
        self.observer = observer
    }

    public func selectedModel(for task: AITask) async throws -> AIModelID {
        try await router.policy(for: task).primary
    }

    public func setModel(
        _ model: AIModelID,
        for task: AITask,
        fallbacks: [AIModelID] = []
    ) async throws {
        try await router.setModel(model, for: task, fallbacks: fallbacks)
    }

    public func rollbackModels() async throws {
        try await router.rollbackToPreviousConfiguration()
    }

    @discardableResult
    public func refreshModels(from source: any AIModelConfigurationSource) async throws -> AIModelConfiguration {
        try await router.refresh(from: source)
        return await router.currentConfiguration()
    }

    public func chat(
        task: AITask = .generalChat,
        systemPrompt: String,
        userMessage: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await complete(
            task: task,
            messages: [
                AIMessage(role: .system, text: systemPrompt),
                AIMessage(role: .user, text: userMessage),
            ],
            modelOverride: modelOverride
        )
    }

    public func analyzeImage(
        _ imageData: Data,
        mimeType: String = "image/jpeg",
        prompt: String,
        task: AITask,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        guard !imageData.isEmpty else { throw AIServiceError.emptyImage }
        let imageURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
        return try await complete(
            task: task,
            messages: [
                AIMessage(role: .user, parts: [
                    .text(prompt),
                    .imageURL(imageURL),
                ])
            ],
            modelOverride: modelOverride
        )
    }

    public func complete(
        task: AITask,
        messages: [AIMessage],
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        let policy = try await router.policy(for: task)
        var candidates = policy.candidates
        if let modelOverride {
            candidates.removeAll { $0 == modelOverride }
            candidates.insert(modelOverride, at: 0)
        }

        let options = AICompletionOptions(
            temperature: policy.temperature,
            maxOutputTokens: policy.maxOutputTokens
        )
        var attempts: [AIModelAttempt] = []

        for (index, model) in candidates.enumerated() {
            let startedAt = Date()
            do {
                let result = try await client.complete(messages: messages, model: model, options: options)
                await observer.record(AIServiceEvent(
                    task: task,
                    requestedModel: model,
                    actualModel: result.model,
                    attempt: index + 1,
                    usedFallback: index > 0,
                    durationMilliseconds: Self.elapsedMilliseconds(since: startedAt),
                    outcome: .success,
                    usage: result.usage
                ))
                return result
            } catch let error as AIServiceError {
                attempts.append(AIModelAttempt(model: model, reason: error.localizedDescription))
                await observer.record(AIServiceEvent(
                    task: task,
                    requestedModel: model,
                    actualModel: nil,
                    attempt: index + 1,
                    usedFallback: index > 0,
                    durationMilliseconds: Self.elapsedMilliseconds(since: startedAt),
                    outcome: Self.outcome(for: error),
                    usage: nil
                ))
                guard error.allowsModelFallback else { throw error }
            } catch {
                attempts.append(AIModelAttempt(model: model, reason: error.localizedDescription))
                await observer.record(AIServiceEvent(
                    task: task,
                    requestedModel: model,
                    actualModel: nil,
                    attempt: index + 1,
                    usedFallback: index > 0,
                    durationMilliseconds: Self.elapsedMilliseconds(since: startedAt),
                    outcome: .unknownFailure,
                    usage: nil
                ))
            }
        }

        throw AIServiceError.allModelsFailed(attempts)
    }

    private static func elapsedMilliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }

    private static func outcome(for error: AIServiceError) -> AIServiceOutcome {
        switch error {
        case .noAPIKey, .http(statusCode: 401, _), .http(statusCode: 403, _):
            .authenticationFailure
        case .http(statusCode: 429, _):
            .rateLimited
        case .http(statusCode: 404, _):
            .modelUnavailable
        case .http(statusCode: 500..., _):
            .providerFailure
        case .transport:
            .transportFailure
        case .invalidResponse, .decoding, .emptyResponse, .invalidStructuredResponse:
            .invalidResponse
        case .missingModelPolicy, .invalidConfiguration, .noPreviousConfiguration, .emptyImage:
            .configurationFailure
        case .allModelsFailed:
            .providerFailure
        case .http:
            .providerFailure
        }
    }
}

public struct AIModelAttempt: Equatable, Sendable {
    public let model: AIModelID
    public let reason: String

    public init(model: AIModelID, reason: String) {
        self.model = model
        self.reason = reason
    }
}

public enum AIServiceError: Error, Equatable, Sendable {
    case noAPIKey
    case missingModelPolicy(AITask)
    case invalidConfiguration(String)
    case noPreviousConfiguration
    case emptyImage
    case invalidStructuredResponse(AITask)
    case transport(String)
    case http(statusCode: Int, message: String)
    case invalidResponse
    case decoding(String)
    case emptyResponse
    case allModelsFailed([AIModelAttempt])

    public var allowsModelFallback: Bool {
        switch self {
        case .transport, .invalidResponse, .decoding, .emptyResponse:
            return true
        case .http(let statusCode, _):
            return statusCode == 404 || statusCode == 408 || statusCode == 409 ||
                statusCode == 429 || statusCode >= 500
        case .noAPIKey, .missingModelPolicy, .invalidConfiguration, .noPreviousConfiguration,
             .emptyImage, .invalidStructuredResponse, .allModelsFailed:
            return false
        }
    }
}

extension AIServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noAPIKey: "DeepSeek API key is missing"
        case .missingModelPolicy(let task): "No model policy for \(task.rawValue)"
        case .invalidConfiguration(let message): "Invalid model configuration: \(message)"
        case .noPreviousConfiguration: "No previous model configuration is available"
        case .emptyImage: "Image data is empty"
        case .invalidStructuredResponse(let task):
            "The model returned invalid structured data for \(task.rawValue)"
        case .transport(let message): "Network error: \(message)"
        case .http(let statusCode, let message): "DeepSeek API error \(statusCode): \(message)"
        case .invalidResponse: "The API returned an invalid response"
        case .decoding(let message): "Could not decode the API response: \(message)"
        case .emptyResponse: "The model returned no content"
        case .allModelsFailed(let attempts):
            "All configured models failed: " + attempts.map { "\($0.model.rawValue): \($0.reason)" }.joined(separator: "; ")
        }
    }
}
