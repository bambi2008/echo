import Foundation
import Testing
@testable import EchoAI

@Suite("AI privacy")
struct AIPrivacyTests {
    @Test("Known identifiers are anonymized and aliases restore locally")
    func aliases() {
        let privacy = AIPrivacyContext(
            people: ["", "Sarah", "Sarah Chen", "sarah"],
            companies: ["Acme Insurance"]
        )
        let original = "Sarah Chen at Acme Insurance asked Sarah to call."

        let anonymized = privacy.anonymize(original)

        #expect(anonymized == "Person B at Company A asked Person A to call.")
        #expect(privacy.restoreAliases(in: anonymized) == original)
        #expect(privacy.alias(for: "SARAH CHEN") == "Person B")
    }

    @Test("Email and phone are redacted without corrupting dates")
    func contactRedaction() {
        let privacy = AIPrivacyContext()
        let value = privacy.anonymize(
            "Date 2026-07-22, email Agent@Test.com, phone +1 (415) 555-0123."
        )

        #expect(value.contains("2026-07-22"))
        #expect(value.contains("[EMAIL]"))
        #expect(value.contains("[PHONE]"))
        #expect(!value.contains("Agent@Test.com"))
        #expect(!value.contains("555-0123"))
    }
}

@Suite("AI observability")
struct AIObservabilityTests {
    @Test("Fallback attempts emit metadata without prompt or error content")
    func fallbackEvents() async throws {
        let client = ObservedClient()
        let observer = RecordingObserver()
        let router = AIModelRouter(defaults: nil)
        try await router.setModel("missing-model", for: .salesCoach, fallbacks: ["working-model"])
        let service = AIService(client: client, router: router, observer: observer)

        let result = try await service.chat(
            task: .salesCoach,
            systemPrompt: "secret system prompt",
            userMessage: "private transcript"
        )

        let events = await observer.events
        #expect(result.model == "working-model")
        #expect(events.count == 2)
        #expect(events[0].requestedModel == "missing-model")
        #expect(events[0].outcome == .modelUnavailable)
        #expect(events[0].attempt == 1)
        #expect(events[0].usedFallback == false)
        #expect(events[1].requestedModel == "working-model")
        #expect(events[1].actualModel == "working-model")
        #expect(events[1].outcome == .success)
        #expect(events[1].attempt == 2)
        #expect(events[1].usedFallback == true)
        #expect(events[1].usage?.totalTokens == 9)
    }
}

private actor ObservedClient: AIProviderClient {
    func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult {
        if model == "missing-model" {
            throw AIServiceError.http(statusCode: 404, message: "private provider details")
        }
        return AIResult(
            text: "ok",
            model: model,
            usage: AIUsage(promptTokens: 5, completionTokens: 4, totalTokens: 9)
        )
    }
}

private actor RecordingObserver: AIServiceObserver {
    private(set) var events: [AIServiceEvent] = []

    func record(_ event: AIServiceEvent) async {
        events.append(event)
    }
}
