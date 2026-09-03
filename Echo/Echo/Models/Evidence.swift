import Foundation
import SwiftData

@Model
final class Evidence {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String?
    var sourceTypeRawValue: String
    var capturedAt: Date
    var excerptOrSummary: String?
    var intelligence: AgentIntelligence?
    var agentAction: AgentAction?

    init(id: UUID = UUID(), title: String, url: String? = nil,
         sourceType: EvidenceSourceType = .other, capturedAt: Date = .now,
         excerptOrSummary: String? = nil, intelligence: AgentIntelligence? = nil,
         agentAction: AgentAction? = nil) {
        self.id = id; self.title = title; self.url = url
        self.sourceTypeRawValue = sourceType.rawValue; self.capturedAt = capturedAt
        self.excerptOrSummary = excerptOrSummary; self.intelligence = intelligence
        self.agentAction = agentAction
    }
    var sourceType: EvidenceSourceType {
        get { EvidenceSourceType(rawValue: sourceTypeRawValue) ?? .other }
        set { sourceTypeRawValue = newValue.rawValue }
    }
}
