import Foundation
import Contacts
import SwiftData

final class ContactImportService {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    @discardableResult
    func importContacts() async throws -> Int {
        let store = CNContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        guard granted else { throw ContactImportError.permissionDenied }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var imported = 0
        try store.enumerateContacts(with: request) { cnContact, _ in
            let phone = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value
            let name = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let existing = self.fetchContact(by: cnContact.identifier)
            if existing == nil {
                let contact = EchoContact(
                    systemIdentifier: cnContact.identifier,
                    givenName: cnContact.givenName,
                    familyName: cnContact.familyName,
                    phoneNumber: phone,
                    emailAddress: email,
                    thumbnailData: cnContact.thumbnailImageData
                )
                modelContext.insert(contact)
                imported += 1
            }
        }
        try capEchoLayer(at: 30)
        try modelContext.save()
        return imported
    }
    private func capEchoLayer(at max: Int) throws {
        let descriptor = FetchDescriptor<EchoContact>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let allContacts = try modelContext.fetch(descriptor)
        for (index, contact) in allContacts.enumerated() {
            contact.isInEchoLayer = index < max
        }
    }
    private func fetchContact(by identifier: String) -> EchoContact? {
        let descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.systemIdentifier == identifier }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

enum ContactImportError: Error, LocalizedError {
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Contacts access was denied. You can enable it in Settings."
        }
    }
}
