import Foundation
import SwiftData

@Model
final class EchoContact {
    @Attribute(.unique) var systemIdentifier: String
    var givenName: String
    var familyName: String
    var phoneNumber: String?
    var emailAddress: String?
    var thumbnailData: Data?
    var isInEchoLayer: Bool
    var priorityRawValue: String?
    var relationshipDomainRawValue: String?
    var lastReachedOut: Date?
    var reachCount: Int
    var tags: [String]
    var companyName: String?
    var jobTitle: String?

    @Relationship(deleteRule: .cascade, inverse: \Interaction.contact)
    var interactions: [Interaction] = []
    @Relationship(deleteRule: .cascade, inverse: \EchoNote.contact)
    var notes: [EchoNote] = []

    init(
        systemIdentifier: String = UUID().uuidString,
        givenName: String,
        familyName: String = "",
        phoneNumber: String? = nil,
        emailAddress: String? = nil,
        isInEchoLayer: Bool = true,
        priority: PriorityLevel? = nil,
        relationshipDomain: RelationshipDomain? = nil,
        lastReachedOut: Date? = nil,
        reachCount: Int = 0,
        companyName: String? = nil,
        jobTitle: String? = nil
    ) {
        self.systemIdentifier = systemIdentifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.isInEchoLayer = isInEchoLayer
        self.priorityRawValue = priority?.rawValue
        self.relationshipDomainRawValue = relationshipDomain?.rawValue
        self.lastReachedOut = lastReachedOut
        self.reachCount = reachCount
        self.tags = []
        self.companyName = companyName
        self.jobTitle = jobTitle
    }

    var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let values = [givenName.first, familyName.first].compactMap { $0 }
        return values.isEmpty ? "?" : String(values)
    }

    var priority: PriorityLevel? {
        get { priorityRawValue.flatMap(PriorityLevel.init(rawValue:)) }
        set { priorityRawValue = newValue?.rawValue }
    }

    var relationshipDomain: RelationshipDomain {
        get {
            relationshipDomainRawValue
                .flatMap(RelationshipDomain.init(rawValue:))
                ?? inferredRelationshipDomain
        }
        set { relationshipDomainRawValue = newValue.rawValue }
    }

    var isPersonalRelationship: Bool {
        relationshipDomain.includes(.personal)
    }

    var isBusinessRelationship: Bool {
        relationshipDomain.includes(.business)
    }

    private var inferredRelationshipDomain: RelationshipDomain {
        let identities = tags.compactMap(ContactIdentity.init(rawValue:))
        let hasPersonalIdentity = identities.contains { $0.domain == .personal }
        let hasBusinessIdentity = identities.contains { $0.domain == .business }
            || companyName != nil
            || jobTitle != nil

        if hasPersonalIdentity && hasBusinessIdentity { return .both }
        if hasBusinessIdentity { return .business }
        return .personal
    }

    var daysSinceContact: Int? {
        let latestInteraction = interactions.map(\.date).max()
        guard let latest = [lastReachedOut, latestInteraction].compactMap({ $0 }).max() else { return nil }
        return Calendar.current.dateComponents([.day], from: latest, to: .now).day
    }
}
