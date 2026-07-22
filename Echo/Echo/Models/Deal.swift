import Foundation
import SwiftData

@Model
final class Deal {
    var title: String
    var value: Double
    var stageRawValue: String
    var nextActionDate: Date?
    var createdAt: Date
    var contact: EchoContact?

    init(
        title: String,
        value: Double = 0,
        stage: DealStage = .lead,
        nextActionDate: Date? = nil,
        contact: EchoContact? = nil
    ) {
        self.title = title
        self.value = value
        self.stageRawValue = stage.rawValue
        self.nextActionDate = nextActionDate
        self.createdAt = .now
        self.contact = contact
    }

    var stage: DealStage {
        get { DealStage(rawValue: stageRawValue) ?? .lead }
        set { stageRawValue = newValue.rawValue }
    }
}
