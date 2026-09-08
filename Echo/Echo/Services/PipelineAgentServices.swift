import EchoAI
import Foundation
import SwiftData

enum PipelineAgentError: LocalizedError {
    case missingOrganizationWebsite
    case invalidWebsite
    case websiteRequestFailed(Int)
    case emptyWebsite
    case missingPrimaryContactEmail
    case emailSentButAuditFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingOrganizationWebsite: String(localized: "Add an organization website before researching it.")
        case .invalidWebsite: String(localized: "The organization website is not a valid HTTPS or HTTP URL.")
        case .websiteRequestFailed(let code): String(localized: "The organization website returned HTTP \(code).")
        case .emptyWebsite: String(localized: "No readable text was found on the organization website.")
        case .missingPrimaryContactEmail: String(localized: "Add an email address to the primary contact first.")
        case .emailSentButAuditFailed(let message): String(localized: "Gmail accepted the email, but Echo could not save its timeline record: \(message)")
        }
    }
}

@MainActor
struct DeepSeekPipelineAgentService: AgentService {
    let features: EchoAIFeatures

    func evaluate(item: Deal, in context: ModelContext) async throws {
        let audit = AgentAction(actionType: .analysis, status: .running,
            summary: String(localized: "Analyzing pipeline context"), source: "DeepSeek",
            pipelineItem: item, organization: item.organization, contact: item.contact)
        context.insert(audit)
        try context.save()
        do {
            let privacy = AIPrivacyContext(
                people: item.allContacts.map(\.fullName),
                companies: [item.organization?.name, item.contact?.companyName].compactMap { $0 }
            )
            let interactions = try context.fetch(FetchDescriptor<Interaction>())
                .filter { interaction in
                    interaction.pipelineItem === item || interaction.organization === item.organization
                        || item.allContacts.contains { contact in contact === interaction.contact }
                }
                .sorted { $0.date > $1.date }
                .prefix(8)
                .map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.actor.title) \($0.type.title) — \($0.summary)" }
                .joined(separator: "\n")
            let evidence = item.intelligence?.evidence.prefix(6).map {
                "\($0.title): \($0.excerptOrSummary ?? "No excerpt")"
            }.joined(separator: "\n") ?? "No captured evidence"
            let rawContext = """
            Item: \(item.title)
            Stage: \(item.stageDefinition.title)
            Priority: \(item.priority.title)
            Organization: \(item.organization?.name ?? "None")
            People: \(item.allContacts.map(\.fullName).joined(separator: ", "))
            Human notes: \(item.humanNotes ?? "None")
            Next action: \(item.nextActionDate?.formatted(date: .abbreviated, time: .omitted) ?? "None")
            Recorded interactions:
            \(interactions.isEmpty ? "None" : interactions)
            Captured evidence:
            \(evidence)
            """
            let result = try await features.pipelineIntelligence(context: privacy.anonymize(rawContext))
            let value = item.intelligence ?? AgentIntelligence(pipelineItem: item)
            if item.intelligence == nil { context.insert(value); item.intelligence = value }
            value.score = result.value.score.map { min(100, max(0, $0)) }
            value.confidence = result.value.confidence.map { min(1, max(0, $0)) }
            value.intentLevel = result.value.intentLevel
            value.summary = privacy.restoreAliases(in: result.value.summary)
            value.whyItMatters = privacy.restoreAliases(in: result.value.whyItMatters)
            value.recommendedNextAction = privacy.restoreAliases(in: result.value.recommendedNextAction)
            value.riskNotes = privacy.restoreAliases(in: result.value.riskNotes)
            value.lastEvaluatedAt = .now
            audit.status = .completed
            audit.summary = String(localized: "Pipeline intelligence updated")
            audit.details = String(localized: "Model: \(result.model.rawValue)")
            try context.save()
        } catch {
            audit.status = .failed
            audit.summary = String(localized: "Pipeline analysis failed")
            audit.details = error.localizedDescription
            try context.save()
            throw error
        }
    }
}

struct WebsiteResearchProvider: ResearchProvider {
    var session: URLSession = .shared

    func research(organization: Organization) async throws -> [Evidence] {
        guard let raw = organization.website?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            throw PipelineAgentError.missingOrganizationWebsite
        }
        let candidate = raw.contains("://") ? raw : "https://\(raw)"
        guard let url = URL(string: candidate), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw PipelineAgentError.invalidWebsite
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Echo/1.0 relationship research", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw PipelineAgentError.websiteRequestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let limited = data.prefix(500_000)
        let html = String(decoding: limited, as: UTF8.self)
        let title = Self.firstMatch(in: html, pattern: #"(?is)<title[^>]*>(.*?)</title>"#)
            .map(Self.cleanHTML) ?? organization.name
        let text = Self.cleanHTML(html)
        guard !text.isEmpty else { throw PipelineAgentError.emptyWebsite }
        return [Evidence(title: title, url: url.absoluteString, sourceType: .web,
                         excerptOrSummary: String(text.prefix(1_500)))]
    }

    private static func firstMatch(in value: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    private static func cleanHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"(?is)<script.*?</script>|<style.*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
struct PipelineResearchCoordinator {
    func research(item: Deal, provider: any ResearchProvider, in context: ModelContext) async throws {
        guard let organization = item.organization else { throw PipelineAgentError.missingOrganizationWebsite }
        let audit = AgentAction(actionType: .research, status: .running,
            summary: String(localized: "Researching organization website"), source: "Website",
            pipelineItem: item, organization: organization, contact: item.contact)
        context.insert(audit)
        try context.save()
        do {
            let evidence = try await provider.research(organization: organization)
            let intelligence = item.intelligence ?? AgentIntelligence(pipelineItem: item)
            if item.intelligence == nil { context.insert(intelligence); item.intelligence = intelligence }
            for source in evidence {
                source.agentAction = audit
                source.intelligence = intelligence
                context.insert(source)
            }
            audit.status = .completed
            audit.summary = String(localized: "Organization website captured")
            audit.details = String(localized: "Stored \(evidence.count) source record(s).")
            try context.save()
        } catch {
            audit.status = .failed
            audit.summary = String(localized: "Website research failed")
            audit.details = error.localizedDescription
            try context.save()
            throw error
        }
    }
}

struct DeepSeekCommunicationProvider: CommunicationProvider {
    let features: EchoAIFeatures

    func prepareOutreach(for item: Deal) async throws -> PreparedOutreach {
        guard let contact = item.contact, contact.emailAddress?.isEmpty == false else {
            throw PipelineAgentError.missingPrimaryContactEmail
        }
        let privacy = AIPrivacyContext(
            people: item.allContacts.map(\.fullName),
            companies: [item.organization?.name, contact.companyName].compactMap { $0 }
        )
        let context = privacy.anonymize("""
        Recipient: \(contact.fullName)
        Organization: \(item.organization?.name ?? contact.companyName ?? "None")
        Pipeline item: \(item.title)
        Stage: \(item.stageDefinition.title)
        Human notes: \(item.humanNotes ?? "None")
        AI recommendation: \(item.intelligence?.recommendedNextAction ?? "None")
        """)
        let result = try await features.pipelineOutreach(context: context)
        return PreparedOutreach(
            subject: privacy.restoreAliases(in: result.value.subject),
            body: privacy.restoreAliases(in: result.value.body),
            model: result.model.rawValue
        )
    }
}

struct GmailEmailDeliveryProvider: EmailDeliveryProvider {
    func send(_ outreach: PreparedOutreach, to recipient: String) async throws -> OutreachDeliveryReceipt {
        let result = try await GmailSyncService.shared.sendEmail(to: recipient, subject: outreach.subject, body: outreach.body)
        return OutreachDeliveryReceipt(externalIdentifier: result.messageID, sentAt: result.sentAt)
    }
}

@MainActor
struct PipelineEmailService {
    func recordPrepared(_ outreach: PreparedOutreach, for item: Deal, in context: ModelContext) throws {
        context.insert(AgentAction(actionType: .outreach, status: .proposed,
            summary: String(localized: "Prepared email draft"), details: String(localized: "Model: \(outreach.model ?? "Unknown")"),
            source: outreach.model == nil ? "Human" : "DeepSeek",
            pipelineItem: item, organization: item.organization, contact: item.contact))
        try context.save()
    }

    @discardableResult
    func send(
        _ outreach: PreparedOutreach,
        for item: Deal,
        using provider: any EmailDeliveryProvider,
        in context: ModelContext
    ) async throws -> OutreachDeliveryReceipt {
        guard let contact = item.contact, let recipient = contact.emailAddress, !recipient.isEmpty else {
            throw PipelineAgentError.missingPrimaryContactEmail
        }
        let receipt: OutreachDeliveryReceipt
        do {
            receipt = try await provider.send(outreach, to: recipient)
        } catch {
            context.insert(AgentAction(actionType: .outreach, status: .failed,
                summary: String(localized: "Gmail send failed"), details: error.localizedDescription,
                source: "Gmail", pipelineItem: item, organization: item.organization, contact: contact))
            try context.save()
            throw error
        }
        do {
            context.insert(Interaction(date: receipt.sentAt, type: .emailed,
                summary: String(localized: "Sent email: \(outreach.subject)"), contact: contact,
                externalIdentifier: "gmail:\(receipt.externalIdentifier):\(contact.systemIdentifier)",
                source: "gmail", isIncoming: false, actor: .human, direction: .outbound,
                pipelineItem: item, organization: item.organization))
            context.insert(AgentAction(timestamp: receipt.sentAt, actionType: .outreach,
                status: .completed, summary: String(localized: "Email sent via Gmail"), details: String(localized: "Subject: \(outreach.subject)"),
                source: "Gmail", pipelineItem: item, organization: item.organization, contact: contact))
            contact.lastReachedOut = max(contact.lastReachedOut ?? .distantPast, receipt.sentAt)
            contact.reachCount += 1
            try context.save()
            return receipt
        } catch {
            throw PipelineAgentError.emailSentButAuditFailed(error.localizedDescription)
        }
    }
}
