import Contacts
import Foundation
import SwiftData

struct ContactImportResult {
    let added: Int
    let updated: Int
}

@MainActor
struct ContactImportService {
    private let store = CNContactStore()

    func importContacts(into context: ModelContext) async throws -> ContactImportResult {
        let allowed = try await requestAccess()
        guard allowed else { return ContactImportResult(added: 0, updated: 0) }

        let storedContacts = try context.fetch(FetchDescriptor<EchoContact>())
        var contactsByIdentifier = Dictionary(uniqueKeysWithValues: storedContacts.map {
            ($0.systemIdentifier, $0)
        })
        var contactsByEmail = Dictionary(grouping: storedContacts.compactMap { contact in
            contact.emailAddress.map { (Self.normalizeEmail($0), contact) }
        }, by: \.0).mapValues { $0.first!.1 }
        var contactsByPhone = Dictionary(grouping: storedContacts.compactMap { contact in
            contact.phoneNumber.map { (Self.normalizePhone($0), contact) }
        }, by: \.0).mapValues { $0.first!.1 }
        let keys = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
        ] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var added = 0
        var updated = 0
        try store.enumerateContacts(with: request) { contact, _ in
            guard !contact.givenName.isEmpty || !contact.familyName.isEmpty else { return }
            let email = contact.emailAddresses.first.map { String($0.value) }
            let phone = contact.phoneNumbers.first?.value.stringValue
            let matched = contactsByIdentifier[contact.identifier]
                ?? email.flatMap { contactsByEmail[Self.normalizeEmail($0)] }
                ?? phone.flatMap { contactsByPhone[Self.normalizePhone($0)] }
            if let matched {
                if Self.update(matched, from: contact, email: email, phone: phone) {
                    updated += 1
                }
                contactsByIdentifier[contact.identifier] = matched
                if let email { contactsByEmail[Self.normalizeEmail(email)] = matched }
                if let phone { contactsByPhone[Self.normalizePhone(phone)] = matched }
                return
            }
            let newContact = EchoContact(
                systemIdentifier: contact.identifier,
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: phone,
                emailAddress: email,
                companyName: contact.organizationName.isEmpty ? nil : contact.organizationName,
                jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle
            )
            context.insert(newContact)
            contactsByIdentifier[contact.identifier] = newContact
            if let email { contactsByEmail[Self.normalizeEmail(email)] = newContact }
            if let phone { contactsByPhone[Self.normalizePhone(phone)] = newContact }
            added += 1
        }
        try context.save()
        return ContactImportResult(added: added, updated: updated)
    }

    private func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    private static func update(
        _ stored: EchoContact,
        from contact: CNContact,
        email: String?,
        phone: String?
    ) -> Bool {
        var changed = false
        func assign(_ value: String?, to keyPath: ReferenceWritableKeyPath<EchoContact, String?>) {
            guard let value, !value.isEmpty, stored[keyPath: keyPath] != value else { return }
            stored[keyPath: keyPath] = value
            changed = true
        }
        if !contact.givenName.isEmpty, stored.givenName != contact.givenName {
            stored.givenName = contact.givenName
            changed = true
        }
        if !contact.familyName.isEmpty, stored.familyName != contact.familyName {
            stored.familyName = contact.familyName
            changed = true
        }
        assign(email, to: \.emailAddress)
        assign(phone, to: \.phoneNumber)
        assign(contact.organizationName.isEmpty ? nil : contact.organizationName, to: \.companyName)
        assign(contact.jobTitle.isEmpty ? nil : contact.jobTitle, to: \.jobTitle)
        return changed
    }

    private static func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizePhone(_ value: String) -> String {
        value.filter(\.isNumber)
    }
}
