import Foundation
import SwiftData

@Model
final class AgentAction {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var actionTypeRawValue: String
    var statusRawValue: String
    var summary: String
    var details: String?
    var source: String?
    var requiresHumanAttention: Bool
    var pipelineItem: Deal?
    var organization: Organization?
    var contact: EchoContact?
    @Relationship(deleteRule: .cascade, inverse: \Evidence.agentAction)
    var evidence: [Evidence] = []

    init(id: UUID = UUID(), timestamp: Date = .now, actionType: AgentActionType,
         status: AgentActionStatus = .completed, summary: String, details: String? = nil,
         source: String? = nil, pipelineItem: Deal? = nil, organization: Organization? = nil,
         contact: EchoContact? = nil, requiresHumanAttention: Bool = false) {
        self.id = id; self.timestamp = timestamp; self.actionTypeRawValue = actionType.rawValue
        self.statusRawValue = status.rawValue; self.summary = summary; self.details = details
        self.source = source; self.pipelineItem = pipelineItem; self.organization = organization
        self.contact = contact; self.requiresHumanAttention = requiresHumanAttention
    }
    var actionType: AgentActionType {
        get { AgentActionType(rawValue: actionTypeRawValue) ?? .other }
        set { actionTypeRawValue = newValue.rawValue }
    }
    var status: AgentActionStatus {
        get { AgentActionStatus(rawValue: statusRawValue) ?? .completed }
        set { statusRawValue = newValue.rawValue }
    }
}
