import Foundation
import SwiftData

/// A preview of a business contact list before it is written to Echo.
///
/// CSV is deliberately parsed locally. No file contents leave the device as
/// part of the import flow.
struct CSVImportPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let contacts: [CSVContactCandidate]

    var newCount: Int { contacts.filter { $0.action == .add }.count }
    var updateCount: Int { contacts.filter { $0.action == .update }.count }
    var unchangedCount: Int { contacts.filter { $0.action == .unchanged }.count }
    var importableCount: Int { newCount + updateCount }
}

struct CSVContactCandidate: Identifiable {
    enum Action: Equatable {
        case add
        case update
        case unchanged
    }

    let id = UUID()
    let displayName: String
    let companyName: String
    let phoneNumber: String?
    let emailAddress: String?
    let website: String?
    let context: String
    let matchedSystemIdentifier: String?
    let action: Action

    var fullName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "Unnamed contact")
            : displayName
    }
}

enum CSVImportError: LocalizedError {
    case emptyFile
    case invalidHeader
    case noContacts

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            String(localized: "The selected CSV file is empty.")
        case .invalidHeader:
            String(localized: "This CSV file does not contain a recognizable business contact column.")
        case .noContacts:
            String(localized: "No business contacts with an email address or phone number were found in this CSV file.")
        }
    }
}

@MainActor
struct CSVImportService {
    func preview(data: Data, fileName: String, in context: ModelContext) throws -> CSVImportPreview {
        guard !data.isEmpty else { throw CSVImportError.emptyFile }
        let text = String(decoding: data, as: UTF8.self)
        let rows = try Self.parse(text)
        guard let header = rows.first, !header.isEmpty else { throw CSVImportError.invalidHeader }

        let headerIndex = Self.headerIndex(header)
        guard headerIndex.company != nil || headerIndex.emailAndPhone != nil else {
            throw CSVImportError.invalidHeader
        }

        var draftsByIdentity: [String: Draft] = [:]
        var draftOrder: [String] = []

        for row in rows.dropFirst() {
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }
            let values = Self.values(row, header: header)
            let companyRaw = Self.value(values, at: headerIndex.company, header: header)
            let contactRaw = Self.value(values, at: headerIndex.emailAndPhone, header: header)
            let email = Self.firstEmail(in: contactRaw ?? "")
                ?? Self.firstEmail(in: Self.value(values, at: headerIndex.email, header: header) ?? "")
            let phone = Self.firstPhone(in: contactRaw ?? "")
                ?? Self.firstPhone(in: Self.value(values, at: headerIndex.phone, header: header) ?? "")
            guard email != nil || phone != nil else { continue }

            let company = (companyRaw ?? "").trimmed
            let displayName = Self.displayName(from: company)
            let context = Self.context(values: values, header: header, excluded: headerIndex)
            let website = Self.firstURL(in: Self.value(values, at: headerIndex.source, header: header) ?? "")
            let draft = Draft(
                displayName: displayName,
                companyName: company.isEmpty ? displayName : company,
                phoneNumber: phone,
                emailAddress: email,
                website: website,
                context: context
            )
            let identity = Self.identityKey(email: email, phone: phone)
            if let identity, var existing = draftsByIdentity[identity] {
                existing = Self.merged(existing, with: draft)
                draftsByIdentity[identity] = existing
            } else {
                let key = identity ?? "row:\(draftOrder.count)"
                draftsByIdentity[key] = draft
                draftOrder.append(key)
            }
        }

        let storedContacts = try context.fetch(FetchDescriptor<EchoContact>())
        let contactsByEmail = Self.lookup(storedContacts, keyPath: \.emailAddress, normalize: Self.normalizeEmail)
        let contactsByPhone = Self.lookup(storedContacts, keyPath: \.phoneNumber, normalize: Self.normalizePhone)

        let candidates = draftOrder.compactMap { key -> CSVContactCandidate? in
            guard let draft = draftsByIdentity[key] else { return nil }
            let match = draft.emailAddress.flatMap { contactsByEmail[Self.normalizeEmail($0)] }
                ?? draft.phoneNumber.flatMap { contactsByPhone[Self.normalizePhone($0)] }
            let action: CSVContactCandidate.Action
            if let match {
                let needsContext = !draft.context.isEmpty
                    && !(match.relationshipContext ?? "").localizedCaseInsensitiveContains(draft.context)
                action = Self.canFillMissingFields(of: match, from: draft) || needsContext ? .update : .unchanged
            } else {
                action = .add
            }
            return CSVContactCandidate(
                displayName: draft.displayName,
                companyName: draft.companyName,
                phoneNumber: draft.phoneNumber,
                emailAddress: draft.emailAddress,
                website: draft.website,
                context: draft.context,
                matchedSystemIdentifier: match?.systemIdentifier,
                action: action
            )
        }

        guard !candidates.isEmpty else { throw CSVImportError.noContacts }
        return CSVImportPreview(fileName: fileName, contacts: candidates)
    }

    @discardableResult
    func importContacts(_ preview: CSVImportPreview, into context: ModelContext) throws -> ContactImportResult {
        let storedContacts = try context.fetch(FetchDescriptor<EchoContact>())
        var contactsByIdentifier = Dictionary(uniqueKeysWithValues: storedContacts.map { ($0.systemIdentifier, $0) })
        var organizations = try context.fetch(FetchDescriptor<Organization>())
        var added = 0
        var updated = 0

        for candidate in preview.contacts {
            switch candidate.action {
            case .add:
                let organization = Self.organization(
                    named: candidate.companyName,
                    website: candidate.website,
                    in: &organizations,
                    context: context
                )
                if organization.notes?.trimmed.nilIfEmpty == nil {
                    organization.notes = candidate.context.nilIfEmpty
                    organization.updatedAt = .now
                }
                let contact = EchoContact(
                    systemIdentifier: "csv:\(UUID().uuidString)",
                    givenName: candidate.displayName,
                    phoneNumber: candidate.phoneNumber,
                    emailAddress: candidate.emailAddress,
                    relationshipDomain: .business,
                    businessRole: .prospect,
                    companyName: candidate.companyName
                )
                contact.organization = organization
                contact.relationshipContext = candidate.context.nilIfEmpty
                if !candidate.context.isEmpty {
                    contact.notes.append(EchoNote(content: candidate.context, contact: contact))
                }
                context.insert(contact)
                contactsByIdentifier[contact.systemIdentifier] = contact
                added += 1
            case .update, .unchanged:
                guard let identifier = candidate.matchedSystemIdentifier,
                      let contact = contactsByIdentifier[identifier]
                else { continue }
                let organization = Self.organization(
                    named: candidate.companyName,
                    website: candidate.website,
                    in: &organizations,
                    context: context
                )
                var changed = false
                if organization.notes?.trimmed.nilIfEmpty == nil, let contextText = candidate.context.nilIfEmpty {
                    organization.notes = contextText
                    organization.updatedAt = .now
                    changed = true
                }
                changed = Self.fill(&contact.phoneNumber, with: candidate.phoneNumber) || changed
                changed = Self.fill(&contact.emailAddress, with: candidate.emailAddress) || changed
                changed = Self.fill(&contact.companyName, with: candidate.companyName) || changed
                if contact.organization == nil {
                    contact.organization = organization
                    changed = true
                }
                if organization.website?.trimmed.nilIfEmpty == nil, let website = candidate.website {
                    organization.website = website
                    organization.updatedAt = .now
                    changed = true
                }
                if contact.relationshipDomain != .business {
                    contact.relationshipDomain = .business
                    changed = true
                }
                if contact.businessRole == .other {
                    contact.businessRole = .prospect
                    changed = true
                }
                if !candidate.context.isEmpty {
                    let oldContext = contact.relationshipContext?.trimmed ?? ""
                    if !oldContext.localizedCaseInsensitiveContains(candidate.context) {
                        contact.relationshipContext = [oldContext, candidate.context]
                            .filter { !$0.isEmpty }
                            .joined(separator: "\n")
                        contact.notes.append(EchoNote(content: candidate.context, contact: contact))
                        changed = true
                    }
                }
                if changed { updated += 1 }
            }
        }

        try context.save()
        return ContactImportResult(added: added, updated: updated)
    }

    // MARK: CSV parsing

    /// RFC 4180-compatible parser. It supports a UTF-8 BOM, quoted commas,
    /// escaped quotes, CRLF and quoted fields containing newlines.
    static func parse(_ text: String) throws -> [[String]] {
        guard !text.isEmpty else { throw CSVImportError.emptyFile }
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\r\n":
                    // Swift represents CRLF as one Character (an extended
                    // grapheme cluster), so handle it before LF-only rows.
                    row.append(field)
                    field = ""
                    if row.contains(where: { !$0.trimmed.isEmpty }) { rows.append(row) }
                    row = []
                case "\n":
                    row.append(field)
                    field = ""
                    if row.last == "\r" { row[row.count - 1] = "" }
                    if row.contains(where: { !$0.trimmed.isEmpty }) { rows.append(row) }
                    row = []
                case "\r":
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\n" {
                        // CRLF is a row separator. Consume both characters but
                        // still finalize the current row. Skipping the LF
                        // without appending the row merges the header with the
                        // first data row and produces an empty preview.
                        row.append(field)
                        field = ""
                        if row.contains(where: { !$0.trimmed.isEmpty }) { rows.append(row) }
                        row = []
                        index = next
                    } else {
                        row.append(field)
                        field = ""
                        if row.contains(where: { !$0.trimmed.isEmpty }) { rows.append(row) }
                        row = []
                    }
                default: field.append(character)
                }
            }
            index = text.index(after: index)
        }

        guard !inQuotes else { throw CSVImportError.invalidHeader }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if row.contains(where: { !$0.trimmed.isEmpty }) { rows.append(row) }
        }
        if let first = rows.first, let value = first.first, value.hasPrefix("\u{FEFF}") {
            rows[0][0] = String(value.dropFirst())
        }
        return rows
    }

    private struct HeaderIndex {
        var company: Int?
        var emailAndPhone: Int?
        var email: Int?
        var phone: Int?
        var source: Int?
    }

    private struct Draft {
        var displayName: String
        var companyName: String
        var phoneNumber: String?
        var emailAddress: String?
        var website: String?
        var context: String
    }

    private static func headerIndex(_ header: [String]) -> HeaderIndex {
        var result = HeaderIndex()
        for (index, rawHeader) in header.enumerated() {
            let key = normalizedHeader(rawHeader)
            if result.company == nil && ["企业/路线", "企业", "公司", "客户", "公司名称", "company", "companyname"].contains(key) {
                result.company = index
            } else if result.emailAndPhone == nil && ["公开商务入口", "商务入口", "联系人", "联系方式", "contact"].contains(key) {
                result.emailAndPhone = index
            } else if result.email == nil && ["邮箱", "email", "emailaddress"].contains(key) {
                result.email = index
            } else if result.phone == nil && ["电话", "手机", "phone", "phonenumber"].contains(key) {
                result.phone = index
            } else if result.source == nil && ["来源", "source", "网址", "website", "url"].contains(key) {
                result.source = index
            }
        }
        return result
    }

    private static func normalizedHeader(_ header: String) -> String {
        header
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func values(_ row: [String], header: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: header.enumerated().map { index, value in
            (normalizedHeader(value), index < row.count ? row[index].trimmed : "")
        })
    }

    private static func value(_ values: [String: String], at index: Int?, header: [String]) -> String? {
        guard let index, index < header.count else { return nil }
        let key = normalizedHeader(header[index])
        guard let value = values[key], !value.isEmpty else { return nil }
        return value
    }

    private static func context(values: [String: String], header: [String], excluded: HeaderIndex) -> String {
        let excludedIndexes = [excluded.company, excluded.emailAndPhone, excluded.email, excluded.phone]
            .compactMap { $0 }
        return header.enumerated().compactMap { index, rawHeader in
            guard !excludedIndexes.contains(index), let value = values[normalizedHeader(rawHeader)], !value.isEmpty else { return nil }
            return "\(rawHeader.trimmed)：\(value)"
        }.joined(separator: "\n")
    }

    private static func displayName(from company: String) -> String {
        let separators = ["／", "/"]
        for separator in separators {
            if let firstValue = company.split(separator: separator, maxSplits: 1).first {
                let first = String(firstValue).trimmed
                if !first.isEmpty { return first }
            }
        }
        return company.trimmed
    }

    private static func firstEmail(in value: String) -> String? {
        let pattern = #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#
        return firstMatch(pattern: pattern, in: value, options: [.caseInsensitive])?.lowercased()
    }

    private static func firstPhone(in value: String) -> String? {
        let pattern = #"\+?[0-9][0-9()\-\s]{5,}[0-9]"#
        guard let match = firstMatch(pattern: pattern, in: value) else { return nil }
        let cleaned = match.replacingOccurrences(of: " ", with: "")
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ";；,，"))
    }

    private static func firstURL(in value: String) -> String? {
        let pattern = #"https?://[^\s]+"#
        guard let match = firstMatch(pattern: pattern, in: value) else { return nil }
        return match.trimmingCharacters(in: CharacterSet(charactersIn: ".,;；)】"))
    }

    private static func firstMatch(pattern: String, in value: String, options: NSRegularExpression.Options = []) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, options: [], range: range),
              let matchRange = Range(match.range, in: value) else { return nil }
        return String(value[matchRange])
    }

    private static func identityKey(email: String?, phone: String?) -> String? {
        if let email {
            let value = normalizeEmail(email)
            if !value.isEmpty { return "email:\(value)" }
        }
        if let phone {
            let value = normalizePhone(phone)
            if !value.isEmpty { return "phone:\(value)" }
        }
        return nil
    }

    private static func merged(_ existing: Draft, with incoming: Draft) -> Draft {
        Draft(
            displayName: existing.displayName.isEmpty ? incoming.displayName : existing.displayName,
            companyName: existing.companyName.isEmpty ? incoming.companyName : existing.companyName,
            phoneNumber: existing.phoneNumber ?? incoming.phoneNumber,
            emailAddress: existing.emailAddress ?? incoming.emailAddress,
            website: existing.website ?? incoming.website,
            context: [existing.context, incoming.context].filter { !$0.isEmpty }.joined(separator: "\n")
        )
    }

    private static func lookup(_ contacts: [EchoContact], keyPath: KeyPath<EchoContact, String?>, normalize: (String) -> String) -> [String: EchoContact] {
        var result: [String: EchoContact] = [:]
        for contact in contacts {
            guard let raw = contact[keyPath: keyPath] else { continue }
            let key = normalize(raw)
            if !key.isEmpty, result[key] == nil { result[key] = contact }
        }
        return result
    }

    private static func canFillMissingFields(of contact: EchoContact, from draft: Draft) -> Bool {
        (!contact.hasRealName && !draft.displayName.isEmpty)
            || contact.phoneNumber?.trimmed.nilIfEmpty == nil && draft.phoneNumber != nil
            || contact.emailAddress?.trimmed.nilIfEmpty == nil && draft.emailAddress != nil
            || contact.companyName?.trimmed.nilIfEmpty == nil && !draft.companyName.isEmpty
            || contact.organization == nil
            || contact.organization?.website?.trimmed.nilIfEmpty == nil && draft.website != nil
    }

    private static func organization(
        named name: String,
        website: String?,
        in organizations: inout [Organization],
        context: ModelContext
    ) -> Organization {
        let key = name.trimmed.lowercased()
        if let existing = organizations.first(where: { $0.name.trimmed.lowercased() == key }) {
            return existing
        }
        let organization = Organization(name: name, website: website)
        organizations.append(organization)
        context.insert(organization)
        return organization
    }

    private static func fill(_ current: inout String?, with incoming: String?) -> Bool {
        guard current?.trimmed.nilIfEmpty == nil, let incoming, !incoming.trimmed.isEmpty else { return false }
        current = incoming
        return true
    }

    private static func normalizeEmail(_ value: String) -> String { value.trimmed.lowercased() }
    private static func normalizePhone(_ value: String) -> String { value.filter(\.isNumber) }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
