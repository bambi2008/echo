import Foundation

/// Business-level AI entry points used by Echo screens and services. Inputs use
/// aliases deliberately so the app can anonymize identifiers before this layer.
public struct EchoAIFeatures: Sendable {
    private let service: AIService

    public init(service: AIService) {
        self.service = service
    }

    public func conversationOpener(
        personAlias: String,
        recentNote: String?,
        daysSinceContact: Int?,
        relationship: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .conversationOpener,
            systemPrompt: """
            You help people stay in touch. Write one warm, natural text message, never corporate or generic. Use only the supplied context and keep it under 40 words.
            """,
            userMessage: """
            Person: \(personAlias)
            Last conversation note: \(recentNote ?? "No prior context")
            Days since last contact: \(daysSinceContact.map(String.init) ?? "Unknown")
            Relationship: \(relationship)
            Suggest one opening message.
            """,
            modelOverride: modelOverride
        )
    }

    public func relationshipInsight(
        personAlias: String,
        interactionSummary: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .relationshipInsight,
            systemPrompt: """
            You identify useful, non-judgmental relationship patterns. State one observation and one gentle next action in under 80 words. Never invent facts.
            """,
            userMessage: """
            Person: \(personAlias)
            Interaction summary: \(interactionSummary)
            Provide one relationship insight.
            """,
            modelOverride: modelOverride
        )
    }

    /// Produces a structured, evidence-led brief for one person. The caller
    /// supplies aliases and restores them locally after the response returns.
    public func relationshipBrief(
        personAlias: String,
        relationship: String,
        lastContact: String,
        interactionSummary: String,
        memorySummary: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<RelationshipBrief> {
        let result = try await service.chat(
            task: .relationshipInsight,
            systemPrompt: """
            You are Echo, a careful relationship memory assistant. Return only valid JSON with exactly these keys:
            {"momentum":"active|steady|cooling|dormant|unknown","headline":"","why_now":"","next_action":"","evidence":[""],"confidence":0}
            Use only supplied facts. Evidence must contain one to three short facts from the input. Do not diagnose, judge, or invent feelings. If evidence is insufficient, use unknown and say so. Keep every string concise and confidence between 0 and 100.
            """,
            userMessage: """
            Person: (personAlias)
            Relationship: (relationship)
            Last contact: (lastContact)
            Interactions: (interactionSummary)
            Memories: (memorySummary)
            """,
            modelOverride: modelOverride
        )
        return try decode(RelationshipBrief.self, from: result, task: .relationshipInsight)
    }

    public func relationshipInsights(
        peopleSummary: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .relationshipInsight,
            systemPrompt: """
            Review a prioritized group of relationships. For every supplied person, write one concise bullet with a useful pattern and one specific next action. Keep the supplied order, use the supplied aliases exactly, stay under 45 words per person, and never invent facts.
            """,
            userMessage: """
            Prioritized people:
            \(peopleSummary)
            """,
            modelOverride: modelOverride
        )
    }

    public func relationshipHealth(
        personAlias: String,
        frequencyTrend: String,
        recentInteractions: String,
        notableChanges: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .relationshipHealth,
            systemPrompt: """
            Assess relationship health and trajectory from supplied interaction data. Be observational, not judgmental. Suggest one gentle action in under 80 words.
            """,
            userMessage: """
            Person: \(personAlias)
            Contact frequency trend: \(frequencyTrend)
            Recent interactions: \(recentInteractions)
            Notable gaps or changes: \(notableChanges)
            """,
            modelOverride: modelOverride
        )
    }

    public func relationshipHealthReview(
        peopleSummary: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .relationshipHealth,
            systemPrompt: """
            Review relationship momentum for every supplied person. For each alias, label the momentum as active, cooling, or dormant, explain the evidence briefly, and suggest one gentle next action. Keep the supplied order, stay under 45 words per person, and never invent facts.
            """,
            userMessage: """
            Prioritized people:
            \(peopleSummary)
            """,
            modelOverride: modelOverride
        )
    }

    public func personRecall(
        memoryDescription: String,
        candidateSummaries: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<PersonRecallResponse> {
        let result = try await service.chat(
            task: .personRecall,
            systemPrompt: """
            Help identify a person from incomplete memory. Rank only the supplied aliases using only supplied evidence. Return at most five matches. Confidence is an integer from 0 to 100 and must reflect ambiguity. Explain the matching clues briefly. Never infer sensitive traits or invent facts. Return only valid JSON:
            {"matches":[{"alias":"Person A","confidence":80,"reason":"Matches the event, industry, and introduction note."}]}
            """,
            userMessage: """
            Memory:
            \(memoryDescription)

            Candidates:
            \(candidateSummaries)
            """,
            modelOverride: modelOverride
        )
        return try decode(PersonRecallResponse.self, from: result, task: .personRecall)
    }

    public func businessCard(
        imageData: Data,
        mimeType: String = "image/jpeg",
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<BusinessCardInfo> {
        let result = try await service.analyzeImage(
            imageData,
            mimeType: mimeType,
            prompt: """
            Extract this business card. Return only valid JSON with exactly these keys. Use an empty string when a field is not visible and never guess:
            {"name":"","company":"","title":"","phone":"","email":"","website":""}
            """,
            task: .businessCardOCR,
            modelOverride: modelOverride
        )
        return try decode(BusinessCardInfo.self, from: result, task: .businessCardOCR)
    }

    public func businessCard(
        extractedText: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<BusinessCardInfo> {
        let result = try await service.chat(
            task: .businessCardOCR,
            systemPrompt: """
            Extract business-card fields from OCR text. Return only valid JSON with exactly these keys. Use an empty string when a field is not visible and never guess:
            {"name":"","company":"","title":"","phone":"","email":"","website":""}
            """,
            userMessage: "OCR text:\n\(extractedText)",
            modelOverride: modelOverride
        )
        return try decode(BusinessCardInfo.self, from: result, task: .businessCardOCR)
    }

    public func policyDocument(
        imageData: Data,
        mimeType: String = "image/jpeg",
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<PolicyDocumentInfo> {
        let result = try await service.analyzeImage(
            imageData,
            mimeType: mimeType,
            prompt: """
            Extract this insurance document. Return only valid JSON with exactly these keys. Use an empty string when a field is missing and never guess:
            {"policy_number":"","insured_name":"","insurance_type":"","premium_amount":"","coverage_amount":"","effective_date":"","expiry_date":"","beneficiary":"","notes":""}
            """,
            task: .policyOCR,
            modelOverride: modelOverride
        )
        return try decode(PolicyDocumentInfo.self, from: result, task: .policyOCR)
    }

    public func policyDocument(
        extractedText: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIStructuredResult<PolicyDocumentInfo> {
        let result = try await service.chat(
            task: .policyOCR,
            systemPrompt: """
            Extract insurance-policy fields from OCR text. Return only valid JSON with exactly these keys. Use an empty string when a field is missing and never guess:
            {"policy_number":"","insured_name":"","insurance_type":"","premium_amount":"","coverage_amount":"","effective_date":"","expiry_date":"","beneficiary":"","notes":""}
            """,
            userMessage: "OCR text:\n\(extractedText)",
            modelOverride: modelOverride
        )
        return try decode(PolicyDocumentInfo.self, from: result, task: .policyOCR)
    }

    public func salesCoaching(
        transcript: String,
        dealStage: String,
        productType: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .salesCoach,
            systemPrompt: """
            You are an expert sales coach. Give exactly one specific, actionable improvement. Be direct, do not add praise, and stay under 100 words.
            """,
            userMessage: """
            Deal stage: \(dealStage)
            Product: \(productType)
            Transcript: \(transcript)
            What should the salesperson do differently next time?
            """,
            modelOverride: modelOverride
        )
    }

    public func dailyBriefing(
        dateDescription: String,
        attentionSummary: String,
        modelOverride: AIModelID? = nil
    ) async throws -> AIResult {
        try await service.chat(
            task: .dailyBriefing,
            systemPrompt: """
            Write a warm, concise morning relationship briefing. Mention at most three supplied people and why each needs attention. Stay under 100 words and never invent facts.
            """,
            userMessage: """
            Date: \(dateDescription)
            People needing attention: \(attentionSummary)
            """,
            modelOverride: modelOverride
        )
    }

    /// Safe local fallback for a failed opener request. The app can substitute
    /// the real first name only after the cloud request has finished.
    public static func openerFallback(personAlias: String) -> String {
        "Hey \(personAlias), been thinking of you! How have you been?"
    }

    private func decode<Value: Decodable & Sendable>(
        _ type: Value.Type,
        from result: AIResult,
        task: AITask
    ) throws -> AIStructuredResult<Value> {
        let json = result.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingMarkdownCodeFence()
        guard let data = json.data(using: .utf8) else {
            throw AIServiceError.invalidStructuredResponse(task)
        }
        do {
            return AIStructuredResult(
                value: try JSONDecoder().decode(type, from: data),
                model: result.model,
                usage: result.usage
            )
        } catch {
            throw AIServiceError.invalidStructuredResponse(task)
        }
    }
}

public struct AIStructuredResult<Value: Sendable>: Sendable {
    public let value: Value
    public let model: AIModelID
    public let usage: AIUsage?

    public init(value: Value, model: AIModelID, usage: AIUsage? = nil) {
        self.value = value
        self.model = model
        self.usage = usage
    }
}

public struct BusinessCardInfo: Codable, Equatable, Sendable {
    public let name: String
    public let company: String
    public let title: String
    public let phone: String
    public let email: String
    public let website: String
}

public struct PersonRecallResponse: Codable, Equatable, Sendable {
    public let matches: [PersonRecallMatch]

    public init(matches: [PersonRecallMatch]) {
        self.matches = matches
    }
}

public struct PersonRecallMatch: Codable, Equatable, Sendable {
    public let alias: String
    public let confidence: Int
    public let reason: String

    public init(alias: String, confidence: Int, reason: String) {
        self.alias = alias
        self.confidence = confidence
        self.reason = reason
    }
}

public struct RelationshipBrief: Codable, Equatable, Sendable {
    public let momentum: String
    public let headline: String
    public let whyNow: String
    public let nextAction: String
    public let evidence: [String]
    public let confidence: Int

    public init(
        momentum: String,
        headline: String,
        whyNow: String,
        nextAction: String,
        evidence: [String],
        confidence: Int
    ) {
        self.momentum = momentum
        self.headline = headline
        self.whyNow = whyNow
        self.nextAction = nextAction
        self.evidence = evidence
        self.confidence = confidence
    }

    enum CodingKeys: String, CodingKey {
        case momentum, headline
        case whyNow = "why_now"
        case nextAction = "next_action"
        case evidence, confidence
    }
}

public struct PolicyDocumentInfo: Codable, Equatable, Sendable {
    public let policyNumber: String
    public let insuredName: String
    public let insuranceType: String
    public let premiumAmount: String
    public let coverageAmount: String
    public let effectiveDate: String
    public let expiryDate: String
    public let beneficiary: String
    public let notes: String

    enum CodingKeys: String, CodingKey {
        case policyNumber = "policy_number"
        case insuredName = "insured_name"
        case insuranceType = "insurance_type"
        case premiumAmount = "premium_amount"
        case coverageAmount = "coverage_amount"
        case effectiveDate = "effective_date"
        case expiryDate = "expiry_date"
        case beneficiary, notes
    }
}

private extension String {
    func removingMarkdownCodeFence() -> String {
        guard hasPrefix("```") else { return self }
        var lines = components(separatedBy: .newlines)
        if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
