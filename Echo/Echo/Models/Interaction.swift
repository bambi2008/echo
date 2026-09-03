import Foundation
import SwiftData

@Model
final class Interaction {
    var date: Date
    var typeRawValue: String
    var summary: String
    var contact: EchoContact?
    var externalIdentifier: String?
    var sourceRawValue: String?
    var isIncoming: Bool?
    var actorRawValue: String?
    var directionRawValue: String?
    var pipelineItem: Deal?
    var organization: Organization?

    init(
        date: Date = .now,
        type: InteractionType,
        summary: String = "",
        contact: EchoContact? = nil,
        externalIdentifier: String? = nil,
        source: String? = nil,
        isIncoming: Bool? = nil,
        actor: InteractionActor = .human,
        direction: InteractionDirection? = nil,
        pipelineItem: Deal? = nil,
        organization: Organization? = nil
    ) {
        self.date = date
        self.typeRawValue = type.rawValue
        self.summary = summary
        self.contact = contact
        self.externalIdentifier = externalIdentifier
        self.sourceRawValue = source
        self.isIncoming = isIncoming
        self.actorRawValue = actor.rawValue
        self.directionRawValue = direction?.rawValue ?? isIncoming.map { $0 ? InteractionDirection.inbound.rawValue : InteractionDirection.outbound.rawValue }
        self.pipelineItem = pipelineItem
        self.organization = organization
    }

    var type: InteractionType {
        get { InteractionType(rawValue: typeRawValue) ?? .reachedOut }
        set { typeRawValue = newValue.rawValue }
    }

    var actor: InteractionActor {
        get { actorRawValue.flatMap(InteractionActor.init(rawValue:)) ?? .human }
        set { actorRawValue = newValue.rawValue }
    }

    var direction: InteractionDirection? {
        get {
            if let raw = directionRawValue, let value = InteractionDirection(rawValue: raw) { return value }
            return isIncoming.map { $0 ? .inbound : .outbound }
        }
        set { directionRawValue = newValue?.rawValue }
    }
}
