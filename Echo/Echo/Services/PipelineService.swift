import Foundation
import SwiftData

enum NextActionFilter: String, CaseIterable, Identifiable {
    case any, due, overdue, unscheduled
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum PipelineSort: String, CaseIterable, Identifiable {
    case newest, nextAction, priority, aiScore
    var id: String { rawValue }
    var title: String {
        switch self { case .nextAction: "Next action"; case .aiScore: "AI score"; default: rawValue.capitalized }
    }
}

struct PipelineFilter {
    var pipelineID: UUID?
    var stageIdentifier: String?
    var humanAttentionOnly = false
    var priority: WorkPriority?
    var organizationID: UUID?
    var nextAction: NextActionFilter = .any
}

enum PipelineQuery {
    static func items(_ items: [Deal], matching filter: PipelineFilter, sortedBy order: PipelineSort, now: Date = .now) -> [Deal] {
        items.filter { item in
            if let id = filter.pipelineID, item.pipeline?.id != id { return false }
            if let stageIdentifier = filter.stageIdentifier, item.stageIdentifier != stageIdentifier { return false }
            if filter.humanAttentionOnly, !item.humanAttentionRequired { return false }
            if let priority = filter.priority, item.priority != priority { return false }
            if let id = filter.organizationID, item.organization?.id != id { return false }
            switch filter.nextAction {
            case .any: break
            case .due:
                guard let date = item.nextActionDate, Calendar.current.isDate(date, inSameDayAs: now) else { return false }
            case .overdue:
                guard let date = item.nextActionDate, date < Calendar.current.startOfDay(for: now) else { return false }
            case .unscheduled:
                guard item.nextActionDate == nil else { return false }
            }
            return true
        }.sorted { lhs, rhs in
            switch order {
            case .newest: return lhs.createdAt > rhs.createdAt
            case .nextAction: return (lhs.nextActionDate ?? .distantFuture) < (rhs.nextActionDate ?? .distantFuture)
            case .priority:
                if lhs.priority.rank != rhs.priority.rank { return lhs.priority.rank > rhs.priority.rank }
                return lhs.createdAt > rhs.createdAt
            case .aiScore:
                let left = lhs.intelligence?.score ?? -1, right = rhs.intelligence?.score ?? -1
                return left == right ? lhs.createdAt > rhs.createdAt : left > right
            }
        }
    }
}

@MainActor
struct PipelineService {
    @discardableResult
    func migrateExistingData(in context: ModelContext) throws -> Pipeline {
        let pipelines = try context.fetch(FetchDescriptor<Pipeline>())
        let fallback = pipelines.first(where: { !$0.isArchived }) ?? {
            let pipeline = Pipeline(name: "Pipeline", description: "Existing and new relationship opportunities")
            context.insert(pipeline)
            return pipeline
        }()

        var organizations = try context.fetch(FetchDescriptor<Organization>())
        let deals = try context.fetch(FetchDescriptor<Deal>())
        for deal in deals {
            if deal.pipeline == nil { deal.pipeline = fallback }
            if deal.updatedAt == nil { deal.updatedAt = deal.createdAt }
            if deal.currency == nil { deal.currency = "USD" }
            if deal.valueIsSet == nil { deal.valueIsSet = deal.value != 0 }
            if let contact = deal.contact, deal.relatedContacts.isEmpty { deal.relatedContacts = [contact] }
            if deal.organization == nil, let contact = deal.contact,
               let company = contact.companyName?.trimmingCharacters(in: .whitespacesAndNewlines), !company.isEmpty {
                let organization = organizations.first { $0.name.localizedCaseInsensitiveCompare(company) == .orderedSame } ?? {
                    let created = Organization(name: company)
                    context.insert(created); organizations.append(created); return created
                }()
                deal.organization = organization
                if contact.organization == nil { contact.organization = organization }
            }
        }
        try context.save()
        return fallback
    }

    func transition(_ item: Deal, to stage: DealStage, source: String = "Echo", in context: ModelContext) throws {
        try transition(item, toStageIdentifier: stage.rawValue, source: source, in: context)
    }

    func transition(_ item: Deal, toStageIdentifier identifier: String, source: String = "Echo", in context: ModelContext) throws {
        let previous = item.stageDefinition
        let next = PipelineStageDefinition(identifier: identifier)
        guard previous.id != next.id else { return }
        item.stageIdentifier = next.id
        if next.legacyStage == .humanAttention { item.humanAttentionRequired = true }
        if next.isClosed {
            item.status = next.legacyStage == .won || next.legacyStage == .closedWon ? .won : .lost
        } else if item.status == .won || item.status == .lost {
            item.status = .active
        }
        context.insert(AgentAction(actionType: .stageChange,
            summary: "Stage changed from \(previous.title) to \(next.title)", source: source,
            pipelineItem: item, organization: item.organization, contact: item.contact))
        try context.save()
    }

    func updateStages(
        for pipeline: Pipeline,
        orderedNames: [String],
        renames: [String: String],
        in context: ModelContext
    ) throws {
        let normalized = orderedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard normalized.count >= 2, normalized.allSatisfy({ !$0.isEmpty }) else {
            throw PipelineStageError.needsTwoStages
        }
        let keys = normalized.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard Set(keys).count == keys.count else { throw PipelineStageError.duplicateName }
        guard normalized.contains(DealStage.won.rawValue), normalized.contains(DealStage.lost.rawValue) else {
            throw PipelineStageError.terminalStagesRequired
        }

        let items = try context.fetch(FetchDescriptor<Deal>()).filter { $0.pipeline?.id == pipeline.id }
        let existing = Set(pipeline.stageRawValues)
        let renamedSources = Set(renames.keys)
        let removed = existing.subtracting(normalized).subtracting(renamedSources)
        if let used = items.first(where: { removed.contains($0.stageIdentifier) }) {
            throw PipelineStageError.stageInUse(used.stageDefinition.title)
        }
        for item in items {
            if let renamed = renames[item.stageIdentifier] { item.stageIdentifier = renamed }
        }
        pipeline.stageRawValues = normalized
        pipeline.updatedAt = .now
        try context.save()
    }

    func setHumanAttention(_ required: Bool, for item: Deal, reason: String? = nil,
                           source: String = "Echo", in context: ModelContext) throws {
        guard item.humanAttentionRequired != required else { return }
        item.humanAttentionRequired = required
        context.insert(AgentAction(actionType: .escalation,
            summary: required ? "Human attention requested" : "Human attention resolved",
            details: reason, source: source, pipelineItem: item, organization: item.organization,
            contact: item.contact, requiresHumanAttention: required))
        try context.save()
    }

    #if DEBUG
    func seedAcceptanceScenario(in context: ModelContext) throws {
        let marker = "echo.agentic.acceptance"
        guard try context.fetch(FetchDescriptor<Deal>()).contains(where: { $0.humanNotes == marker }) == false else { return }
        let pipeline = Pipeline(name: "Partnerships", description: "Sample agentic workflow", objective: "Develop trusted partnerships", agentEnabled: true, autonomyLevel: .supervised)
        let organization = Organization(name: "Organization A", website: "https://example.org", industry: "Technology", notes: "Locally generated verification scenario")
        let first = EchoContact(systemIdentifier: "echo.agentic.person.1", givenName: "Person", familyName: "One", companyName: organization.name, jobTitle: "Founder")
        let second = EchoContact(systemIdentifier: "echo.agentic.person.2", givenName: "Person", familyName: "Two", companyName: organization.name, jobTitle: "Partnerships")
        first.organization = organization; second.organization = organization
        let item = Deal(title: "Potential Partnership", stage: .opportunity,
                        nextActionDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                        contact: first, pipeline: pipeline, organization: organization,
                        priority: .high, humanAttentionRequired: true, humanNotes: marker,
                        relatedContacts: [first, second])
        let intelligence = AgentIntelligence(score: 86, confidence: 0.78, intentLevel: "High",
            summary: "Two engaged stakeholders and a clear shared objective.",
            whyItMatters: "The relationship is ready for a direct, thoughtful conversation.",
            recommendedNextAction: "Review the context and arrange a short call.",
            riskNotes: "Decision timing is not yet confirmed.", pipelineItem: item)
        item.intelligence = intelligence
        let research = AgentAction(timestamp: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now,
            actionType: .research, summary: "Reviewed organization source",
            details: "Captured a source for the local acceptance scenario.", source: "Local acceptance fixture",
            pipelineItem: item, organization: organization, contact: first)
        let evidence = Evidence(title: "Organization website", url: "https://example.org", sourceType: .web,
                                excerptOrSummary: "Public organization overview", intelligence: intelligence, agentAction: research)
        let progression = [
            AgentAction(timestamp: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now,
                actionType: .stageChange, summary: "Stage changed from Discovered to Qualified", source: "Local acceptance fixture", pipelineItem: item, organization: organization, contact: first),
            AgentAction(timestamp: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
                actionType: .stageChange, summary: "Stage changed from Qualified to Contacted", source: "Local acceptance fixture", pipelineItem: item, organization: organization, contact: first),
            AgentAction(timestamp: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
                actionType: .stageChange, summary: "Stage changed from Contacted to Engaged", source: "Local acceptance fixture", pipelineItem: item, organization: organization, contact: first),
            AgentAction(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                actionType: .stageChange, summary: "Stage changed from Engaged to Opportunity", source: "Local acceptance fixture", pipelineItem: item, organization: organization, contact: first),
        ]
        let escalation = AgentAction(actionType: .escalation, summary: "Escalated after qualification",
            details: "Human judgment is useful before outreach.", source: "Sample local agent",
            pipelineItem: item, organization: organization, contact: first, requiresHumanAttention: true)
        let incoming = Interaction(date: Calendar.current.date(byAdding: .hour, value: -8, to: .now) ?? .now,
            type: .emailed, summary: "Asked for a follow-up conversation", contact: second,
            source: "Local acceptance fixture", actor: .external, direction: .inbound,
            pipelineItem: item, organization: organization)
        let meeting = Interaction(date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
            type: .metInPerson, summary: "Discussed shared goals", contact: first,
            source: "Local acceptance fixture", actor: .human, direction: .outbound,
            pipelineItem: item, organization: organization)

        let secondOrganization = Organization(name: "Organization B", industry: "Education", location: "Remote", notes: "Second organization for layout and filtering verification")
        let third = EchoContact(systemIdentifier: "echo.agentic.person.3", givenName: "Person", familyName: "Three", companyName: secondOrganization.name, jobTitle: "Director")
        let fourth = EchoContact(systemIdentifier: "echo.agentic.person.4", givenName: "Person", familyName: "Four", companyName: secondOrganization.name, jobTitle: "Advisor")
        third.organization = secondOrganization; fourth.organization = secondOrganization
        let secondItem = Deal(title: "Explore Collaboration", stage: .qualified,
            nextActionDate: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            contact: third, pipeline: pipeline, organization: secondOrganization,
            priority: .medium, humanNotes: "Secondary local verification item", relatedContacts: [third, fourth])

        context.insert(pipeline); context.insert(organization); context.insert(secondOrganization)
        [first, second, third, fourth].forEach(context.insert)
        context.insert(item); context.insert(secondItem); context.insert(intelligence); context.insert(research)
        progression.forEach(context.insert)
        context.insert(evidence); context.insert(escalation); context.insert(incoming); context.insert(meeting)
        try context.save()
    }
    #endif
}

// External systems write through these boundaries instead of coupling to SwiftUI.
@MainActor protocol AgentService { func evaluate(item: Deal, in context: ModelContext) async throws }
@MainActor protocol ResearchProvider { func research(organization: Organization) async throws -> [Evidence] }
@MainActor protocol CommunicationProvider { func prepareOutreach(for item: Deal) async throws -> PreparedOutreach }
@MainActor protocol EmailDeliveryProvider { func send(_ outreach: PreparedOutreach, to recipient: String) async throws -> OutreachDeliveryReceipt }

struct PreparedOutreach: Equatable {
    let subject: String
    let body: String
    let model: String?
}

struct OutreachDeliveryReceipt: Equatable {
    let externalIdentifier: String
    let sentAt: Date
}

enum PipelineStageError: LocalizedError {
    case needsTwoStages, duplicateName, terminalStagesRequired, stageInUse(String)
    var errorDescription: String? {
        switch self {
        case .needsTwoStages: "Keep at least two named stages."
        case .duplicateName: "Each stage needs a unique name."
        case .terminalStagesRequired: "Won and Lost are protected terminal stages."
        case .stageInUse(let name): "Move items out of \(name) before deleting it."
        }
    }
}
