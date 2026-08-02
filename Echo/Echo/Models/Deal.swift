import Foundation
import SwiftData

@Model
final class Deal {
    var title: String
    var value: Double
    var stage: DealStage.RawValue
    var expectedCloseDate: Date?
    var probability: Double
    var createdAt: Date = Date()
    @Relationship var contact: EchoContact?
    init(title: String, value: Double = 0, stage: DealStage = .lead, expectedCloseDate: Date? = nil, probability: Double = 0.1) {
        self.title = title
        self.value = value
        self.stage = stage.rawValue
        self.expectedCloseDate = expectedCloseDate
        self.probability = probability
    }
    var dealStage: DealStage { DealStage(rawValue: stage) ?? .lead }
}
