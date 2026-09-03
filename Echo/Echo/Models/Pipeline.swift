import Foundation
import SwiftData

struct PipelineStageDefinition: Identifiable, Hashable {
    let id: String

    init(identifier: String) {
        id = identifier
    }

    var legacyStage: DealStage? { DealStage(rawValue: id) }
    var title: String { legacyStage?.title ?? id }
    var displayTitle: String {
        guard legacyStage != nil else { return id }
        return String(localized: String.LocalizationValue(title))
    }
    var symbol: String { legacyStage?.symbol ?? "circle.fill" }
    var isClosed: Bool { legacyStage?.isClosed == true }
    var isProtectedTerminal: Bool { legacyStage == .won || legacyStage == .lost }
}

@Model
final class Pipeline {
    @Attribute(.unique) var id: UUID
    var name: String
    var pipelineDescription: String
    var objective: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var agentEnabled: Bool
    var agentAutonomyLevelRawValue: String
    var stageRawValues: [String]
    var usesMonetaryValue: Bool
    @Relationship(deleteRule: .nullify, inverse: \Deal.pipeline)
    var items: [Deal] = []

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        objective: String = "",
        createdAt: Date = .now,
        isArchived: Bool = false,
        agentEnabled: Bool = false,
        autonomyLevel: AgentAutonomyLevel = .assist,
        stages: [DealStage] = DealStage.defaultAgenticStages,
        usesMonetaryValue: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pipelineDescription = description
        self.objective = objective
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isArchived = isArchived
        self.agentEnabled = agentEnabled
        self.agentAutonomyLevelRawValue = autonomyLevel.rawValue
        self.stageRawValues = stages.map(\.rawValue)
        self.usesMonetaryValue = usesMonetaryValue
    }

    var autonomyLevel: AgentAutonomyLevel {
        get { AgentAutonomyLevel(rawValue: agentAutonomyLevelRawValue) ?? .assist }
        set { agentAutonomyLevelRawValue = newValue.rawValue; updatedAt = .now }
    }

    var stages: [DealStage] {
        let stored = stageRawValues.compactMap(DealStage.init(rawValue:))
        return stored.isEmpty ? DealStage.defaultAgenticStages : stored
    }

    @MainActor var stageDefinitions: [PipelineStageDefinition] {
        let identifiers = stageRawValues.isEmpty ? DealStage.defaultAgenticStages.map(\.rawValue) : stageRawValues
        return identifiers.map(PipelineStageDefinition.init(identifier:))
    }
}
