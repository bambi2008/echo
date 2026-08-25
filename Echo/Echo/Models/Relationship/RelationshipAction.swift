import Foundation
import SwiftData

@Model
final class RelationshipAction {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var plannedFor: Date?
    var completedAt: Date?
    var typeRawValue: String
    var statusRawValue: String
    var note: String?
    var reflectionID: UUID?
    var journeyID: UUID?
    var contact: EchoContact?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        plannedFor: Date? = nil,
        completedAt: Date? = nil,
        type: RelationshipActionType,
        status: RelationshipActionStatus = .planned,
        note: String? = nil,
        reflectionID: UUID? = nil,
        journeyID: UUID? = nil,
        contact: EchoContact? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.plannedFor = plannedFor
        self.completedAt = completedAt
        self.typeRawValue = type.rawValue
        self.statusRawValue = status.rawValue
        self.note = note
        self.reflectionID = reflectionID
        self.journeyID = journeyID
        self.contact = contact
    }

    var type: RelationshipActionType {
        get { RelationshipActionType(rawValue: typeRawValue) ?? .remember }
        set { typeRawValue = newValue.rawValue }
    }
    var status: RelationshipActionStatus {
        get { RelationshipActionStatus(rawValue: statusRawValue) ?? .planned }
        set { statusRawValue = newValue.rawValue }
    }
}
