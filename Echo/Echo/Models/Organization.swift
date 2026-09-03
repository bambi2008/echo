import Foundation
import SwiftData

@Model
final class Organization {
    @Attribute(.unique) var id: UUID
    var name: String
    var website: String?
    var domain: String?
    var industry: String?
    var location: String?
    var country: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .nullify, inverse: \EchoContact.organization)
    var contacts: [EchoContact] = []
    @Relationship(deleteRule: .nullify, inverse: \Deal.organization)
    var pipelineItems: [Deal] = []

    init(id: UUID = UUID(), name: String, website: String? = nil, domain: String? = nil,
         industry: String? = nil, location: String? = nil, country: String? = nil,
         notes: String? = nil, createdAt: Date = .now) {
        self.id = id; self.name = name; self.website = website; self.domain = domain
        self.industry = industry; self.location = location; self.country = country
        self.notes = notes; self.createdAt = createdAt; self.updatedAt = createdAt
    }
}
