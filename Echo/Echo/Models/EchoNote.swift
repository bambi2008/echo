import Foundation
import SwiftData

@Model
final class EchoNote {
    var createdAt: Date
    var content: String
    var isVoice: Bool
    var contact: EchoContact?

    init(createdAt: Date = .now, content: String, isVoice: Bool = false, contact: EchoContact? = nil) {
        self.createdAt = createdAt
        self.content = content
        self.isVoice = isVoice
        self.contact = contact
    }
}
