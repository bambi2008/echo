import Foundation
import SwiftData

@Model
final class AgentIntelligence {
    @Attribute(.unique) var id: UUID
    var score: Int?
    var confidence: Double?
    var intentLevel: String?
    var summary: String?
    var whyItMatters: String?
    var recommendedNextAction: String?
    var riskNotes: String?
    var lastEvaluatedAt: Date?
    var pipelineItem: Deal?
    @Relationship(deleteRule: .cascade, inverse: \Evidence.intelligence)
    var evidence: [Evidence] = []

    init(id: UUID = UUID(), score: Int? = nil, confidence: Double? = nil,
         intentLevel: String? = nil, summary: String? = nil, whyItMatters: String? = nil,
         recommendedNextAction: String? = nil, riskNotes: String? = nil,
         lastEvaluatedAt: Date? = .now, pipelineItem: Deal? = nil) {
        self.id = id; self.score = score.map { min(100, max(0, $0)) }
        self.confidence = confidence.map { min(1, max(0, $0)) }; self.intentLevel = intentLevel
        self.summary = summary; self.whyItMatters = whyItMatters
        self.recommendedNextAction = recommendedNextAction; self.riskNotes = riskNotes
        self.lastEvaluatedAt = lastEvaluatedAt; self.pipelineItem = pipelineItem
    }
}
