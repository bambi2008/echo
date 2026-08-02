import Foundation
import SwiftData

@Model
final class EchoContact {
    @Attribute(.unique) var systemIdentifier: String
    var givenName: String
    var familyName: String
    var fullName: String { "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces) }
    var phoneNumber: String?
    var emailAddress: String?
    var thumbnailData: Data?
    var isInEchoLayer: Bool = true
    var priorityLevel: PriorityLevel.RawValue?
    var dealStage: DealStage.RawValue?
    var dealValue: Double?
    var nextActionDate: Date?
    var companyName: String?
    var jobTitle: String?
    var lastReachedOut: Date?
    var reachCount: Int = 0
    var createdAt: Date = Date()
    var aiInsight: String?
    var aiInsightDate: Date?
    @Relationship(deleteRule: .cascade) var interactions: [Interaction] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    init(systemIdentifier: String, givenName: String, familyName: String = "", phoneNumber: String? = nil, emailAddress: String? = nil, thumbnailData: Data? = nil) {
        self.systemIdentifier = systemIdentifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.thumbnailData = thumbnailData
    }
}
