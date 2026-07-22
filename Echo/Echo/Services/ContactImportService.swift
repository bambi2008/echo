import Contacts
import Foundation
import SwiftData

@MainActor
struct ContactImportService {
    private let store = CNContactStore()

    func importContacts(into context: ModelContext) async throws -> Int {
        let allowed = try await requestAccess()
        guard allowed else { return 0 }

        let existing = Set(try context.fetch(FetchDescriptor<EchoContact>()).map(\.systemIdentifier))
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
        var count = 0
        try store.enumerateContacts(with: request) { contact, _ in
            guard !existing.contains(contact.identifier),
                  !contact.givenName.isEmpty || !contact.familyName.isEmpty
            else { return }
            context.insert(EchoContact(
                systemIdentifier: contact.identifier,
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: contact.phoneNumbers.first?.value.stringValue,
                emailAddress: contact.emailAddresses.first.map { String($0.value) },
                companyName: contact.organizationName.isEmpty ? nil : contact.organizationName,
                jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle
            ))
            count += 1
        }
        try context.save()
        return count
    }

    private func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }
}
