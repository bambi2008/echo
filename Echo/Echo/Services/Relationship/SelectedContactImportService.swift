import Contacts
import Foundation
import SwiftData

@MainActor
struct SelectedContactImportService {
    static let requestedKeys: [String] = [
        CNContactIdentifierKey,
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactOrganizationNameKey,
        CNContactJobTitleKey,
        CNContactThumbnailImageDataKey,
    ]

    func importSelected(_ selected: [CNContact], into context: ModelContext) throws -> [EchoContact] {
        let stored = try context.fetch(FetchDescriptor<EchoContact>())
        var byIdentifier = Dictionary(uniqueKeysWithValues: stored.map { ($0.systemIdentifier, $0) })
        var byEmail = Dictionary(grouping: stored.compactMap { contact in
            contact.emailAddress.map { (normalizeEmail($0), contact) }
        }, by: \.0).compactMapValues { $0.first?.1 }
        var byPhone = Dictionary(grouping: stored.compactMap { contact in
            contact.phoneNumber.map { (normalizePhone($0), contact) }
        }, by: \.0).compactMapValues { $0.first?.1 }
        var imported: [EchoContact] = []

        for source in selected {
            let email = source.emailAddresses.first.map { String($0.value) }
            let phone = source.phoneNumbers.first?.value.stringValue
            let match = byIdentifier[source.identifier]
                ?? email.flatMap { byEmail[normalizeEmail($0)] }
                ?? phone.flatMap { byPhone[normalizePhone($0)] }
            if let match {
                fillMissingFields(of: match, from: source, email: email, phone: phone)
                match.relationshipJourneyIncluded = true
                imported.append(match)
                continue
            }
            let contact = EchoContact(
                systemIdentifier: source.identifier,
                givenName: source.givenName,
                familyName: source.familyName,
                phoneNumber: phone,
                emailAddress: email,
                relationshipDomain: .business,
                companyName: source.organizationName.nilIfEmpty,
                jobTitle: source.jobTitle.nilIfEmpty
            )
            contact.thumbnailData = source.thumbnailImageData
            contact.relationshipJourneyIncluded = true
            context.insert(contact)
            byIdentifier[source.identifier] = contact
            if let email { byEmail[normalizeEmail(email)] = contact }
            if let phone { byPhone[normalizePhone(phone)] = contact }
            imported.append(contact)
        }
        try context.save()
        return imported
    }

    private func fillMissingFields(
        of contact: EchoContact,
        from source: CNContact,
        email: String?,
        phone: String?
    ) {
        if !contact.hasRealName, !source.givenName.isEmpty || !source.familyName.isEmpty {
            contact.givenName = source.givenName
            contact.familyName = source.familyName
        }
        if contact.emailAddress == nil { contact.emailAddress = email }
        if contact.phoneNumber == nil { contact.phoneNumber = phone }
        if contact.companyName == nil { contact.companyName = source.organizationName.nilIfEmpty }
        if contact.jobTitle == nil { contact.jobTitle = source.jobTitle.nilIfEmpty }
        if contact.thumbnailData == nil { contact.thumbnailData = source.thumbnailImageData }
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizePhone(_ value: String) -> String { value.filter(\.isNumber) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
