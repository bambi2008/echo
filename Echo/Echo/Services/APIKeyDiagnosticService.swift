import EchoAI
import Foundation

enum APIKeyPresence: Equatable {
    case configured
    case notConfigured
    case unavailable
}

struct APIKeyDiagnosticService {
    private let keyStore: any AIAPIKeyStore
    private let client: any AIProviderClient
    private let router: AIModelRouter

    init(
        keyStore: any AIAPIKeyStore = KeychainAPIKeyStore(),
        router: AIModelRouter = AIModelRouter()
    ) {
        self.keyStore = keyStore
        self.client = DeepSeekClient(apiKeyStore: keyStore)
        self.router = router
    }

    init(
        keyStore: any AIAPIKeyStore,
        client: any AIProviderClient,
        router: AIModelRouter
    ) {
        self.keyStore = keyStore
        self.client = client
        self.router = router
    }

    func presence() -> APIKeyPresence {
        do {
            let key = try keyStore.readAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
            return key?.isEmpty == false ? .configured : .notConfigured
        } catch {
            return .unavailable
        }
    }

    func testConnection() async throws -> AIModelID {
        guard presence() == .configured else { throw AIServiceError.noAPIKey }
        let model = try await router.policy(for: .generalChat).primary
        let result = try await client.complete(
            messages: [
                AIMessage(role: .system, text: "Reply with OK only."),
                AIMessage(role: .user, text: "Connection test"),
            ],
            model: model,
            options: AICompletionOptions(
                temperature: 0,
                maxOutputTokens: 16,
                thinkingEnabled: false
            )
        )
        return result.model
    }
}
