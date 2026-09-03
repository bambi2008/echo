import Foundation
import SwiftData

@Model
final class Deal {
    var title: String
    var value: Double
    var stageRawValue: String
    var nextActionDate: Date?
    var createdAt: Date
    var contact: EchoContact?
    // Optional/defaulted additions keep automatic migration safe for existing Deal records.
    var updatedAt: Date?
    var currency: String?
    var valueIsSet: Bool?
    var priorityRawValue: String?
    var statusRawValue: String?
    var humanAttentionRequiredRaw: Bool?
    var humanNotes: String?
    var pipeline: Pipeline?
    var organization: Organization?
    @Relationship(deleteRule: .nullify)
    var relatedContacts: [EchoContact] = []
    @Relationship(deleteRule: .cascade, inverse: \AgentIntelligence.pipelineItem)
    var intelligence: AgentIntelligence?
    @Relationship(deleteRule: .cascade, inverse: \AgentAction.pipelineItem)
    var agentActions: [AgentAction] = []

    init(
        title: String,
        value: Double? = nil,
        currency: String = "USD",
        stage: DealStage = .discovered,
        nextActionDate: Date? = nil,
        contact: EchoContact? = nil,
        pipeline: Pipeline? = nil,
        organization: Organization? = nil,
        priority: WorkPriority = .medium,
        status: PipelineItemStatus = .active,
        humanAttentionRequired: Bool = false,
        humanNotes: String? = nil,
        relatedContacts: [EchoContact] = []
    ) {
        self.title = title
        self.value = value ?? 0
        self.stageRawValue = stage.rawValue
        self.nextActionDate = nextActionDate
        self.createdAt = .now
        self.contact = contact
        self.updatedAt = .now
        self.currency = currency
        self.valueIsSet = value != nil
        self.priorityRawValue = priority.rawValue
        self.statusRawValue = status.rawValue
        self.humanAttentionRequiredRaw = humanAttentionRequired
        self.humanNotes = humanNotes
        self.pipeline = pipeline
        self.organization = organization
        self.relatedContacts = relatedContacts
    }

    var stage: DealStage {
        get { DealStage(rawValue: stageRawValue) ?? .discovered }
        set { stageRawValue = newValue.rawValue; updatedAt = .now }
    }

    var stageIdentifier: String {
        get { stageRawValue }
        set { stageRawValue = newValue; updatedAt = .now }
    }

    @MainActor var stageDefinition: PipelineStageDefinition {
        PipelineStageDefinition(identifier: stageRawValue)
    }

    var hasMonetaryValue: Bool { valueIsSet ?? (value != 0) }
    var resolvedCurrency: String { currency?.isEmpty == false ? currency! : "USD" }
    var priority: WorkPriority {
        get { priorityRawValue.flatMap(WorkPriority.init(rawValue:)) ?? .medium }
        set { priorityRawValue = newValue.rawValue; updatedAt = .now }
    }
    var status: PipelineItemStatus {
        get {
            if let stored = statusRawValue.flatMap(PipelineItemStatus.init(rawValue:)) { return stored }
            if [.won, .closedWon].contains(stage) { return .won }
            if [.lost, .closedLost].contains(stage) { return .lost }
            return .active
        }
        set { statusRawValue = newValue.rawValue; updatedAt = .now }
    }
    var humanAttentionRequired: Bool {
        get { humanAttentionRequiredRaw ?? (stage == .humanAttention) }
        set { humanAttentionRequiredRaw = newValue; updatedAt = .now }
    }
    var allContacts: [EchoContact] {
        var result = relatedContacts
        if let contact, !result.contains(where: { $0.systemIdentifier == contact.systemIdentifier }) {
            result.insert(contact, at: 0)
        }
        return result
    }
}
