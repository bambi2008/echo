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

    init(
        date: Date = .now,
        type: InteractionType,
        summary: String = "",
        contact: EchoContact? = nil,
        externalIdentifier: String? = nil,
        source: String? = nil,
        isIncoming: Bool? = nil
    ) {
        self.date = date
        self.typeRawValue = type.rawValue
        self.summary = summary
        self.contact = contact
        self.externalIdentifier = externalIdentifier
        self.sourceRawValue = source
        self.isIncoming = isIncoming
    }

    var type: InteractionType {
        get { InteractionType(rawValue: typeRawValue) ?? .reachedOut }
        set { typeRawValue = newValue.rawValue }
    }
}
