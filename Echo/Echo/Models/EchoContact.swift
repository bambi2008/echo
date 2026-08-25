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
    var facebookUsername: String?
    var xUsername: String?
    var redditUsername: String?
    var telegramUsername: String?
    var discordUsername: String?
    var linkedinUsername: String?
    var instagramUsername: String?
    var whatsappNumber: String?
    var relationshipIntentRawValue: String?
    var desiredCadenceDays: Int?
    var lastRelationshipReviewAt: Date?
    var relationshipContext: String?
    var relationshipJourneyIncluded: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Interaction.contact)
    var interactions: [Interaction] = []
    @Relationship(deleteRule: .cascade, inverse: \EchoNote.contact)
    var notes: [EchoNote] = []
    @Relationship(deleteRule: .cascade, inverse: \RelationshipReflection.contact)
    var relationshipReflections: [RelationshipReflection] = []
    @Relationship(deleteRule: .cascade, inverse: \RelationshipAction.contact)
    var relationshipActions: [RelationshipAction] = []

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
        jobTitle: String? = nil,
        facebookUsername: String? = nil,
        xUsername: String? = nil,
        redditUsername: String? = nil,
        telegramUsername: String? = nil,
        discordUsername: String? = nil,
        linkedinUsername: String? = nil,
        instagramUsername: String? = nil,
        whatsappNumber: String? = nil
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
        self.facebookUsername = facebookUsername
        self.xUsername = xUsername
        self.redditUsername = redditUsername
        self.telegramUsername = telegramUsername
        self.discordUsername = discordUsername
        self.linkedinUsername = linkedinUsername
        self.instagramUsername = instagramUsername
        self.whatsappNumber = whatsappNumber
        self.relationshipIntentRawValue = nil
        self.desiredCadenceDays = nil
        self.lastRelationshipReviewAt = nil
        self.relationshipContext = nil
        self.relationshipJourneyIncluded = false
    }

    var fullName: String {
        hasRealName ? storedName : "未命名联系人"
    }

    var hasRealName: Bool {
        let candidate = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }

        let normalized = candidate.lowercased()
        if ["unknown contact", "unnamed contact", "未命名联系人"].contains(normalized) {
            return false
        }
        if let companyName,
           familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           normalized == companyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return false
        }
        if let emailAddress {
            let emailName = emailAddress.split(separator: "@").first.map(String.init)?.lowercased()
            if normalized == emailName { return false }
        }
        let nameDigits = candidate.filter(\.isNumber)
        if let phoneNumber {
            let phoneDigits = phoneNumber.filter(\.isNumber)
            if !phoneDigits.isEmpty, nameDigits == phoneDigits { return false }
        }
        let phonePunctuation = CharacterSet(charactersIn: "+-() .")
        if !nameDigits.isEmpty,
           candidate.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) || phonePunctuation.contains($0) }) {
            return false
        }
        return true
    }

    var isEligibleForTodaysEcho: Bool {
        hasRealName && hasRelationshipContext
    }

    var initials: String {
        guard hasRealName else { return "?" }
        let values = [givenName.first, familyName.first].compactMap { $0 }
        return values.isEmpty ? "?" : String(values)
    }

    private var storedName: String {
        [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var hasRelationshipContext: Bool {
        relationshipDomainRawValue != nil
            || priorityRawValue != nil
            || !tags.isEmpty
            || companyName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || !notes.isEmpty
            || !interactions.isEmpty
    }

    var priority: PriorityLevel? {
        get { priorityRawValue.flatMap(PriorityLevel.init(rawValue:)) }
        set { priorityRawValue = newValue?.rawValue }
    }

    var relationshipIntent: RelationshipIntent? {
        get { relationshipIntentRawValue.flatMap(RelationshipIntent.init(rawValue:)) }
        set { relationshipIntentRawValue = newValue?.rawValue }
    }

    var desiredCadenceTitle: String {
        switch desiredCadenceDays {
        case 7: String(localized: "Weekly")
        case 30: String(localized: "Monthly")
        case 90: String(localized: "Quarterly")
        case .some(let days): String(localized: "Every \(days) days")
        case nil: String(localized: "No fixed rhythm")
        }
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

    var availableSocialPlatforms: [SocialPlatform] {
        SocialPlatform.allCases.filter { socialIdentifier(for: $0) != nil }
    }

    func socialIdentifier(for platform: SocialPlatform) -> String? {
        switch platform {
        case .facebook: facebookUsername
        case .x: xUsername
        case .reddit: redditUsername
        case .telegram: telegramUsername
        case .discord: discordUsername
        case .linkedin: linkedinUsername
        case .instagram: instagramUsername
        case .whatsapp: whatsappNumber ?? phoneNumber
        }
    }

    func setSocialIdentifier(_ value: String?, for platform: SocialPlatform) {
        switch platform {
        case .facebook: facebookUsername = value
        case .x: xUsername = value
        case .reddit: redditUsername = value
        case .telegram: telegramUsername = value
        case .discord: discordUsername = value
        case .linkedin: linkedinUsername = value
        case .instagram: instagramUsername = value
        case .whatsapp: whatsappNumber = value
        }
    }
}
