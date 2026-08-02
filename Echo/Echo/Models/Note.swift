import Foundation
import SwiftData

@Model
final class Note {
    var content: String
    var createdAt: Date = Date()
    @Relationship(inverse: \EchoContact.notes) var contact: EchoContact?
    init(content: String) {
        self.content = content
    }
}
