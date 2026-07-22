import Foundation
import SwiftData

@Model
final class Interaction {
    var date: Date
    var typeRawValue: String
    var summary: String
    var contact: EchoContact?

    init(date: Date = .now, type: InteractionType, summary: String = "", contact: EchoContact? = nil) {
        self.date = date
        self.typeRawValue = type.rawValue
        self.summary = summary
        self.contact = contact
    }

    var type: InteractionType {
        get { InteractionType(rawValue: typeRawValue) ?? .reachedOut }
        set { typeRawValue = newValue.rawValue }
    }
}
