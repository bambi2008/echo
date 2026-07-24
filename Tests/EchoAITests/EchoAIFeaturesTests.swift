import Foundation
import Testing
@testable import EchoAI

@Suite("Echo AI feature integration")
struct EchoAIFeaturesTests {
    @Test("Business features route through their task-specific models")
    func taskRouting() async throws {
        let client = QueueClient(responses: [
            AIResult(text: "opener", model: "deepseek-v4-flash"),
            AIResult(text: "insight", model: "deepseek-v4-flash"),
            AIResult(text: "health", model: "deepseek-v4-pro"),
            AIResult(text: "coach", model: "deepseek-v4-pro"),
            AIResult(text: "briefing", model: "deepseek-v4-flash"),
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        _ = try await features.conversationOpener(
            personAlias: "Person A",
            recentNote: "Asked about a project",
            daysSinceContact: 10,
            relationship: "friend"
        )
        _ = try await features.relationshipInsight(
            personAlias: "Person A",
            interactionSummary: "Monthly calls"
        )
        _ = try await features.relationshipHealth(
            personAlias: "Person A",
            frequencyTrend: "stable",
            recentInteractions: "three calls",
            notableChanges: "none"
        )
        _ = try await features.salesCoaching(
            transcript: "Person A mentioned budget.",
            dealStage: "quoted",
            productType: "insurance"
        )
        _ = try await features.dailyBriefing(
            dateDescription: "2026-07-22",
            attentionSummary: "Person A: follow-up due"
        )

        #expect(await client.models == [
            "deepseek-v4-flash",
            "deepseek-v4-flash",
            "deepseek-v4-pro",
            "deepseek-v4-pro",
            "deepseek-v4-flash",
        ])
    }

    @Test("Business card JSON is decoded with model metadata")
    func businessCardDecoding() async throws {
        let client = QueueClient(responses: [
            AIResult(
                text: """
                ```json
                {"name":"A","company":"B","title":"C","phone":"1","email":"a@b.com","website":"https://b.com"}
                ```
                """,
                model: "vision-model",
                usage: AIUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15)
            )
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        let result = try await features.businessCard(
            imageData: Data([1]),
            modelOverride: "vision-model"
        )

        #expect(result.value.company == "B")
        #expect(result.value.email == "a@b.com")
        #expect(result.model == "vision-model")
        #expect(result.usage?.totalTokens == 15)
    }

    @Test("Policy JSON uses stable typed field names")
    func policyDecoding() async throws {
        let client = QueueClient(responses: [
            AIResult(
                text: """
                {"policy_number":"P1","insured_name":"Person A","insurance_type":"Term","premium_amount":"100","coverage_amount":"1000","effective_date":"2026-01-01","expiry_date":"2027-01-01","beneficiary":"Person B","notes":""}
                """,
                model: "policy-model"
            )
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        let result = try await features.policyDocument(
            imageData: Data([1]),
            modelOverride: "policy-model"
        )

        #expect(result.value.policyNumber == "P1")
        #expect(result.value.insuredName == "Person A")
        #expect(result.value.coverageAmount == "1000")
    }

    @Test("On-device OCR text can be structured as a business card")
    func businessCardTextDecoding() async throws {
        let client = QueueClient(responses: [
            AIResult(
                text: #"{"name":"Ada Lee","company":"Echo","title":"Founder","phone":"123","email":"ada@example.com","website":"echo.example"}"#,
                model: "deepseek-v4-pro"
            )
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        let result = try await features.businessCard(
            extractedText: "Ada Lee\nFounder\nEcho\nada@example.com"
        )

        #expect(result.value.name == "Ada Lee")
        #expect(result.value.title == "Founder")
        #expect(result.model == "deepseek-v4-pro")
    }

    @Test("On-device OCR text can be structured as a policy")
    func policyTextDecoding() async throws {
        let client = QueueClient(responses: [
            AIResult(
                text: #"{"policy_number":"E-42","insured_name":"Person A","insurance_type":"Life","premium_amount":"100","coverage_amount":"1000","effective_date":"2026-01-01","expiry_date":"2027-01-01","beneficiary":"Person B","notes":""}"#,
                model: "deepseek-v4-pro"
            )
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        let result = try await features.policyDocument(
            extractedText: "Policy E-42\nLife\nCoverage 1000"
        )

        #expect(result.value.policyNumber == "E-42")
        #expect(result.value.insuranceType == "Life")
    }

    @Test("Malformed OCR output is rejected")
    func malformedJSON() async throws {
        let client = QueueClient(responses: [
            AIResult(text: "not json", model: "vision-model")
        ])
        let features = EchoAIFeatures(
            service: AIService(client: client, router: AIModelRouter(defaults: nil))
        )

        await #expect(throws: AIServiceError.invalidStructuredResponse(.businessCardOCR)) {
            try await features.businessCard(imageData: Data([1]))
        }
    }
}

private actor QueueClient: AIProviderClient {
    private var responses: [AIResult]
    private(set) var models: [AIModelID] = []

    init(responses: [AIResult]) {
        self.responses = responses
    }

    func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult {
        models.append(model)
        guard !responses.isEmpty else { throw AIServiceError.emptyResponse }
        return responses.removeFirst()
    }
}
