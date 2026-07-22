import Foundation
import Testing
@testable import EchoAI

@Suite("AI model routing")
struct AIModelRouterTests {
    @Test("Any model ID can be activated without changing an enum")
    func arbitraryModelID() async throws {
        let router = AIModelRouter(defaults: nil)
        try await router.setModel(
            AIModelID(rawValue: "deepseek-future-best-model"),
            for: .conversationOpener,
            fallbacks: ["deepseek-v4-pro"]
        )

        let policy = try await router.policy(for: .conversationOpener)
        #expect(policy.primary.rawValue == "deepseek-future-best-model")
        #expect(policy.fallbacks == ["deepseek-v4-pro"])
    }

    @Test("A request override wins without changing the stored policy")
    func perRequestOverride() async throws {
        let client = RecordingClient(outcomes: [
            "one-off-model": .success(AIResult(text: "ok", model: "one-off-model"))
        ])
        let router = AIModelRouter(defaults: nil)
        let service = AIService(client: client, router: router)

        let result = try await service.chat(
            task: .generalChat,
            systemPrompt: "system",
            userMessage: "hello",
            modelOverride: "one-off-model"
        )

        #expect(result.model == "one-off-model")
        #expect(try await router.policy(for: .generalChat).primary == "deepseek-v4-flash")
    }

    @Test("Unavailable primary model falls back in declared order")
    func fallback() async throws {
        let client = RecordingClient(outcomes: [
            "bad-model": .failure(.http(statusCode: 404, message: "model not found")),
            "working-model": .success(AIResult(text: "fallback", model: "working-model")),
        ])
        let router = AIModelRouter(defaults: nil)
        try await router.setModel("bad-model", for: .salesCoach, fallbacks: ["working-model"])
        let service = AIService(client: client, router: router)

        let result = try await service.chat(
            task: .salesCoach,
            systemPrompt: "coach",
            userMessage: "transcript"
        )

        #expect(result.text == "fallback")
        #expect(await client.requestedModels == ["bad-model", "working-model"])
    }

    @Test("Authentication errors never rotate through models")
    func noFallbackForAuthentication() async throws {
        let client = RecordingClient(outcomes: [
            "bad-auth": .failure(.http(statusCode: 401, message: "unauthorized")),
            "unused": .success(AIResult(text: "should not run", model: "unused")),
        ])
        let router = AIModelRouter(defaults: nil)
        try await router.setModel("bad-auth", for: .dailyBriefing, fallbacks: ["unused"])
        let service = AIService(client: client, router: router)

        await #expect(throws: AIServiceError.http(statusCode: 401, message: "unauthorized")) {
            try await service.chat(
                task: .dailyBriefing,
                systemPrompt: "brief",
                userMessage: "today"
            )
        }
        #expect(await client.requestedModels == ["bad-auth"])
    }

    @Test("Configuration round trips as editable JSON")
    func configurationJSON() async throws {
        let router = AIModelRouter(defaults: nil)
        let data = try await router.exportConfiguration()
        let decoded = try AIModelRouter.decoder.decode(AIModelConfiguration.self, from: data)

        #expect(decoded.policies[.generalChat]?.primary == "deepseek-v4-flash")
        #expect(decoded.policies.count == AITask.allCases.count)
    }

    @Test("Retired DeepSeek aliases migrate without touching custom models")
    func retiredAliasMigration() throws {
        var legacy = AIModelConfiguration.deepSeekV4
        legacy.policies[.generalChat]?.primary = "deepseek-chat"
        legacy.policies[.salesCoach]?.primary = "deepseek-reasoner"
        legacy.policies[.businessCardOCR]?.primary = "deepseek-vision"
        legacy.policies[.dailyBriefing]?.primary = "my-custom-model"

        let migrated = AIModelRouter.migrateRetiredAliases(in: legacy)

        #expect(migrated.policies[.generalChat]?.primary == "deepseek-v4-flash")
        #expect(migrated.policies[.salesCoach]?.primary == "deepseek-v4-pro")
        #expect(migrated.policies[.businessCardOCR]?.primary == "deepseek-v4-pro")
        #expect(migrated.policies[.dailyBriefing]?.primary == "my-custom-model")
    }

    @Test("A complete configuration replacement can be rolled back")
    func rollback() async throws {
        let suite = "EchoAITests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let router = AIModelRouter(
            defaults: UserDefaults(suiteName: suite)
        )

        var replacement = AIModelConfiguration.deepSeekV4
        replacement.policies[.generalChat]?.primary = "candidate-model"
        try await router.replaceConfiguration(replacement)
        #expect(try await router.policy(for: .generalChat).primary == "candidate-model")

        try await router.rollbackToPreviousConfiguration()
        #expect(try await router.policy(for: .generalChat).primary == "deepseek-v4-flash")
    }
}

private actor RecordingClient: AIProviderClient {
    enum Outcome: Sendable {
        case success(AIResult)
        case failure(AIServiceError)
    }

    private let outcomes: [String: Outcome]
    private(set) var requestedModels: [AIModelID] = []

    init(outcomes: [String: Outcome]) {
        self.outcomes = outcomes
    }

    func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult {
        requestedModels.append(model)
        switch outcomes[model.rawValue] {
        case .success(let result): return result
        case .failure(let error): throw error
        case nil: throw AIServiceError.http(statusCode: 404, message: "unconfigured mock")
        }
    }
}
