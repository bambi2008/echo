import Contacts
import Foundation
import SwiftData

struct VCFImportPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let contacts: [VCFContactCandidate]

    var newCount: Int { contacts.filter { $0.action == .add }.count }
    var updateCount: Int { contacts.filter { $0.action == .update }.count }
    var unchangedCount: Int { contacts.filter { $0.action == .unchanged }.count }
    var importableCount: Int { newCount + updateCount }
}

struct VCFContactCandidate: Identifiable {
    enum Action {
        case add
        case update
        case unchanged
    }

    let id = UUID()
    let givenName: String
    let familyName: String
    let phoneNumber: String?
    let emailAddress: String?
    let companyName: String?
    let jobTitle: String?
    let relationshipDomain: RelationshipDomain
    let matchedSystemIdentifier: String?
    let action: Action

    var fullName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "未命名联系人" : name
    }
}

enum VCFImportError: LocalizedError {
    case emptyFile
    case noContacts

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            "The selected VCF file is empty."
        case .noContacts:
            "No contacts with a name, email, or phone number were found in this VCF file."
        }
    }
}

@MainActor
struct VCFImportService {
    func preview(data: Data, fileName: String, in context: ModelContext) throws -> VCFImportPreview {
        guard !data.isEmpty else { throw VCFImportError.emptyFile }

        let vCardContacts = try CNContactVCardSerialization.contacts(with: data)
        let storedContacts = try context.fetch(FetchDescriptor<EchoContact>())
        let contactsByEmail = Self.lookup(storedContacts, value: \EchoContact.emailAddress, normalize: Self.normalizeEmail)
        let contactsByPhone = Self.lookup(storedContacts, value: \EchoContact.phoneNumber, normalize: Self.normalizePhone)
        let drafts = Self.mergedDrafts(from: vCardContacts)

        let candidates = drafts.map { draft in
            let match = draft.emailAddress.flatMap { contactsByEmail[Self.normalizeEmail($0)] }
                ?? draft.phoneNumber.flatMap { contactsByPhone[Self.normalizePhone($0)] }
            let action: VCFContactCandidate.Action
            if let match {
                action = Self.canFillMissingFields(of: match, from: draft) ? .update : .unchanged
            } else {
                action = .add
            }
            return VCFContactCandidate(
                givenName: draft.givenName,
                familyName: draft.familyName,
                phoneNumber: draft.phoneNumber,
                emailAddress: draft.emailAddress,
                companyName: draft.companyName,
                jobTitle: draft.jobTitle,
                relationshipDomain: match?.relationshipDomain ?? Self.suggestedRelationship(for: draft),
                matchedSystemIdentifier: match?.systemIdentifier,
                action: action
            )
        }

        guard !candidates.isEmpty else { throw VCFImportError.noContacts }
        return VCFImportPreview(fileName: fileName, contacts: candidates)
    }

    func importContacts(
        _ preview: VCFImportPreview,
        relationshipOverrides: [UUID: RelationshipDomain] = [:],
        into context: ModelContext
    ) throws -> ContactImportResult {
        let storedContacts = try context.fetch(FetchDescriptor<EchoContact>())
        var contactsByIdentifier = Dictionary(uniqueKeysWithValues: storedContacts.map { ($0.systemIdentifier, $0) })
        var added = 0
        var updated = 0

        for candidate in preview.contacts {
            let selectedRelationship = relationshipOverrides[candidate.id] ?? candidate.relationshipDomain
            switch candidate.action {
            case .add:
                let contact = EchoContact(
                    systemIdentifier: "vcf:\(UUID().uuidString)",
                    givenName: candidate.givenName,
                    familyName: candidate.familyName,
                    phoneNumber: candidate.phoneNumber,
                    emailAddress: candidate.emailAddress,
                    relationshipDomain: selectedRelationship,
                    companyName: candidate.companyName,
                    jobTitle: candidate.jobTitle
                )
                context.insert(contact)
                contactsByIdentifier[contact.systemIdentifier] = contact
                added += 1
            case .update:
                guard let identifier = candidate.matchedSystemIdentifier,
                      let contact = contactsByIdentifier[identifier]
                else { continue }
                let filledMissingFields = Self.fillMissingFields(of: contact, from: candidate)
                let changedRelationship = Self.updateRelationship(
                    of: contact,
                    to: selectedRelationship
                )
                if filledMissingFields || changedRelationship {
                    updated += 1
                }
            case .unchanged:
                guard let identifier = candidate.matchedSystemIdentifier,
                      let contact = contactsByIdentifier[identifier]
                else { continue }
                if Self.updateRelationship(of: contact, to: selectedRelationship) {
                    updated += 1
                }
            }
        }

        try context.save()
        return ContactImportResult(added: added, updated: updated)
    }

    private struct Draft {
        var givenName: String
        var familyName: String
        var phoneNumber: String?
        var emailAddress: String?
        var companyName: String?
        var jobTitle: String?
    }

    private static func mergedDrafts(from contacts: [CNContact]) -> [Draft] {
        var drafts: [Draft] = []
        var indexByIdentity: [String: Int] = [:]

        for contact in contacts {
            let email = contact.emailAddresses.first.map { String($0.value).trimmed.nilIfEmpty }.flatMap { $0 }
            let phone = contact.phoneNumbers.first?.value.stringValue.trimmed.nilIfEmpty
            let organization = contact.organizationName.trimmed.nilIfEmpty
            let jobTitle = contact.jobTitle.trimmed.nilIfEmpty
            let givenName = contact.givenName.trimmed
            let familyName = contact.familyName.trimmed

            guard !givenName.isEmpty || !familyName.isEmpty || email != nil || phone != nil else { continue }

            let draft = Draft(
                givenName: givenName,
                familyName: familyName,
                phoneNumber: phone,
                emailAddress: email,
                companyName: organization,
                jobTitle: jobTitle
            )
            let keys = identityKeys(email: email, phone: phone)
            if let existingIndex = keys.compactMap({ indexByIdentity[$0] }).first {
                drafts[existingIndex] = merged(drafts[existingIndex], with: draft)
                for key in identityKeys(email: drafts[existingIndex].emailAddress, phone: drafts[existingIndex].phoneNumber) {
                    indexByIdentity[key] = existingIndex
                }
            } else {
                let newIndex = drafts.count
                drafts.append(draft)
                for key in keys { indexByIdentity[key] = newIndex }
            }
        }
        return drafts
    }

    private static func merged(_ existing: Draft, with incoming: Draft) -> Draft {
        Draft(
            givenName: existing.givenName.isEmpty ? incoming.givenName : existing.givenName,
            familyName: existing.familyName.isEmpty ? incoming.familyName : existing.familyName,
            phoneNumber: existing.phoneNumber ?? incoming.phoneNumber,
            emailAddress: existing.emailAddress ?? incoming.emailAddress,
            companyName: existing.companyName ?? incoming.companyName,
            jobTitle: existing.jobTitle ?? incoming.jobTitle
        )
    }

    private static func identityKeys(email: String?, phone: String?) -> [String] {
        var keys: [String] = []
        if let email {
            let normalized = normalizeEmail(email)
            if !normalized.isEmpty { keys.append("email:\(normalized)") }
        }
        if let phone {
            let normalized = normalizePhone(phone)
            if !normalized.isEmpty { keys.append("phone:\(normalized)") }
        }
        return keys
    }

    private static func lookup(
        _ contacts: [EchoContact],
        value: KeyPath<EchoContact, String?>,
        normalize: (String) -> String
    ) -> [String: EchoContact] {
        var result: [String: EchoContact] = [:]
        for contact in contacts {
            guard let rawValue = contact[keyPath: value] else { continue }
            let normalized = normalize(rawValue)
            guard !normalized.isEmpty, result[normalized] == nil else { continue }
            result[normalized] = contact
        }
        return result
    }

    private static func canFillMissingFields(of contact: EchoContact, from draft: Draft) -> Bool {
        (!contact.hasRealName && (!draft.givenName.isEmpty || !draft.familyName.isEmpty))
            || (contact.phoneNumber?.trimmed.nilIfEmpty == nil && draft.phoneNumber != nil)
            || (contact.emailAddress?.trimmed.nilIfEmpty == nil && draft.emailAddress != nil)
            || (contact.companyName?.trimmed.nilIfEmpty == nil && draft.companyName != nil)
            || (contact.jobTitle?.trimmed.nilIfEmpty == nil && draft.jobTitle != nil)
    }

    private static func suggestedRelationship(for draft: Draft) -> RelationshipDomain {
        draft.companyName != nil || draft.jobTitle != nil ? .business : .personal
    }

    private static func updateRelationship(
        of contact: EchoContact,
        to relationship: RelationshipDomain
    ) -> Bool {
        guard contact.relationshipDomain != relationship else { return false }
        contact.relationshipDomain = relationship
        return true
    }

    private static func fillMissingFields(of contact: EchoContact, from candidate: VCFContactCandidate) -> Bool {
        var changed = false
        if !contact.hasRealName && (!candidate.givenName.isEmpty || !candidate.familyName.isEmpty) {
            contact.givenName = candidate.givenName
            contact.familyName = candidate.familyName
            changed = true
        }
        changed = fill(&contact.phoneNumber, with: candidate.phoneNumber) || changed
        changed = fill(&contact.emailAddress, with: candidate.emailAddress) || changed
        changed = fill(&contact.companyName, with: candidate.companyName) || changed
        changed = fill(&contact.jobTitle, with: candidate.jobTitle) || changed
        return changed
    }

    private static func fill(_ current: inout String?, with incoming: String?) -> Bool {
        guard current?.trimmed.nilIfEmpty == nil, let incoming else { return false }
        current = incoming
        return true
    }

    private static func normalizeEmail(_ value: String) -> String {
        value.trimmed.lowercased()
    }

    private static func normalizePhone(_ value: String) -> String {
        value.filter(\.isNumber)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
