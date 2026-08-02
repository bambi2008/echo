import Foundation
import SwiftData

@Model
final class Interaction {
    var type: InteractionType.RawValue
    var date: Date = Date()
    var note: String = ""
    @Relationship(inverse: \EchoContact.interactions) var contact: EchoContact?
    init(type: InteractionType, note: String = "") {
        self.type = type.rawValue
        self.note = note
    }
    var interactionType: InteractionType { InteractionType(rawValue: type) ?? .reachedOut }
}
