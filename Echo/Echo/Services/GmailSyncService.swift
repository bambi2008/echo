import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftData
import UIKit

struct GmailConnectionStatus {
    let email: String
    let expiresAt: Date
    let lastSyncAt: Date?
    let canImportContacts: Bool
    let canSendEmail: Bool
}

struct GmailSendResult {
    let messageID: String
    let threadID: String?
    let sentAt: Date
}

enum GmailMessageEncoder {
    static func encodedMessage(to recipient: String, subject: String, body: String) throws -> String {
        let cleanRecipient = recipient.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        let matches = GmailSyncService.emails(in: cleanRecipient)
        let normalizedRecipient = cleanRecipient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard matches.count == 1, matches.first == normalizedRecipient else {
            throw GmailSyncError.provider(statusCode: 400, message: "The recipient email address is invalid.")
        }
        let cleanSubject = subject.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let encodedSubject = Data(cleanSubject.utf8).base64EncodedString()
        let encodedBody = Data(body.utf8).base64EncodedString(options: .endLineWithCarriageReturn)
        let message = [
            "To: \(cleanRecipient)",
            "Subject: =?UTF-8?B?\(encodedSubject)?=",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: base64",
            "",
            encodedBody,
        ].joined(separator: "\r\n")
        return Data(message.utf8).base64URLEncoded
    }
}

struct GmailSyncResult {
    let importedInteractions: Int
    let messagesScanned: Int
    let matchedMessages: Int
    let lastSyncAt: Date
    let wasIncremental: Bool

    var unmatchedMessages: Int {
        max(0, messagesScanned - matchedMessages)
    }
}

struct GoogleContactImportResult {
    let added: Int
    let updated: Int
    let skipped: Int
    let savedContactsFound: Int
    let otherContactsFound: Int
}

private struct GmailToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String?
    var historyID: String?
    var lastSyncAt: Date?
    var grantedScopes: String?
}

private struct GmailTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Double
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct GmailProfile: Decodable {
    let emailAddress: String
    let historyID: String

    enum CodingKeys: String, CodingKey {
        case emailAddress
        case historyID = "historyId"
    }
}

private struct GmailMessageList: Decodable {
    let messages: [GmailMessageReference]?
    let nextPageToken: String?
}

private struct GmailMessageReference: Decodable {
    let id: String
}

private struct GmailSentMessage: Decodable {
    let id: String
    let threadId: String?
}

private struct GmailMessage: Decodable {
    let id: String
    let labelIds: [String]?
    let internalDate: String?
    let payload: GmailPayload?
}

private struct GmailPayload: Decodable {
    let headers: [GmailHeader]?
}

private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

private struct GmailHistoryList: Decodable {
    let history: [GmailHistoryRecord]?
    let nextPageToken: String?
}

private struct GmailHistoryRecord: Decodable {
    let messagesAdded: [GmailHistoryMessage]?
}

private struct GmailHistoryMessage: Decodable {
    let message: GmailMessageReference
}

private struct GmailProviderErrorEnvelope: Decodable {
    let error: GmailProviderErrorBody
}

private struct GmailProviderErrorBody: Decodable {
    let message: String
}

private struct GooglePeopleResponse: Decodable {
    let connections: [GooglePerson]?
    let nextPageToken: String?
}

private struct GoogleOtherContactsResponse: Decodable {
    let otherContacts: [GooglePerson]?
    let nextPageToken: String?
}

private struct GooglePerson: Decodable {
    let resourceName: String
    let names: [GooglePersonName]?
    let emailAddresses: [GooglePersonValue]?
    let phoneNumbers: [GooglePersonValue]?
    let organizations: [GoogleOrganization]?
    let urls: [GooglePersonValue]?
    let imClients: [GoogleIMClient]?
}

private struct GooglePersonName: Decodable {
    let givenName: String?
    let familyName: String?
    let displayName: String?
}

private struct GooglePersonValue: Decodable {
    let value: String?
    let type: String?
}

private struct GoogleOrganization: Decodable {
    let name: String?
    let title: String?
    let current: Bool?
}

private struct GoogleIMClient: Decodable {
    let username: String?
    let protocolName: String?
    let formattedProtocol: String?

    enum CodingKeys: String, CodingKey {
        case username
        case protocolName = "protocol"
        case formattedProtocol
    }
}

enum GmailSyncError: LocalizedError {
    case notConnected
    case invalidConfiguration
    case authorizationFailed
    case provider(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConnected: String(localized: "Connect Gmail before syncing.")
        case .invalidConfiguration: String(localized: "Gmail OAuth is not configured correctly.")
        case .authorizationFailed: String(localized: "Google authorization did not complete.")
        case .provider(let statusCode, let message):
            switch statusCode {
            case 401:
                String(localized: "Google access has expired. Disconnect Gmail and connect it again.")
            case 403:
                message.contains("Reconnect")
                    ? String(localized: String.LocalizationValue(message))
                    : String(localized: "Google did not allow this request. Reconnect Google and make sure People API is enabled.")
            case 429:
                String(localized: "Gmail is temporarily rate-limiting Echo. Wait a moment and try again.")
            default:
                String(localized: "Gmail request failed: \(message)")
            }
        }
    }
}

@MainActor
final class GmailSyncService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GmailSyncService()

    private let clientID = "584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5.apps.googleusercontent.com"
    private let callbackScheme = "com.googleusercontent.apps.584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5"
    private let scope = [
        "https://www.googleapis.com/auth/gmail.metadata",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/contacts.other.readonly",
    ].joined(separator: " ")
    private let tokenStore = GmailTokenStore()
    private var authenticationSession: ASWebAuthenticationSession?

    func status() -> GmailConnectionStatus? {
        guard let token = try? tokenStore.read(), let email = token.email else { return nil }
        return GmailConnectionStatus(
            email: email,
            expiresAt: token.expiresAt,
            lastSyncAt: token.lastSyncAt,
            canImportContacts: Self.hasContactScopes(token.grantedScopes),
            canSendEmail: Self.hasSendScope(token.grantedScopes)
        )
    }

    func connect() async throws -> GmailConnectionStatus {
        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let redirectURI = "\(callbackScheme):/oauthredirect"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent select_account"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizationURL = components.url else { throw GmailSyncError.invalidConfiguration }

        let callbackURL = try await authorize(url: authorizationURL)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw GmailSyncError.authorizationFailed }

        var token = try await exchange(code: code, verifier: verifier, redirectURI: redirectURI)
        let profile = try await profile(accessToken: token.accessToken)
        token.email = profile.emailAddress
        try tokenStore.save(token)
        return GmailConnectionStatus(
            email: token.email ?? "",
            expiresAt: token.expiresAt,
            lastSyncAt: token.lastSyncAt,
            canImportContacts: true,
            canSendEmail: true
        )
    }

    func disconnect() throws {
        try tokenStore.delete()
    }

    func sendEmail(to recipient: String, subject: String, body: String) async throws -> GmailSendResult {
        let token = try await validToken()
        guard Self.hasSendScope(token.grantedScopes) else {
            throw GmailSyncError.provider(statusCode: 403, message: "Reconnect Google to approve sending email from Echo.")
        }
        let raw = try GmailMessageEncoder.encodedMessage(to: recipient, subject: subject, body: body)
        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["raw": raw])
        let sent: GmailSentMessage = try await decode(request)
        return GmailSendResult(messageID: sent.id, threadID: sent.threadId, sentAt: .now)
    }

    func shouldSync(minimumInterval: TimeInterval = 15 * 60) -> Bool {
        guard let token = try? tokenStore.read() else { return false }
        guard let lastSyncAt = token.lastSyncAt else { return true }
        return Date.now.timeIntervalSince(lastSyncAt) >= minimumInterval
    }

    func sync(contacts: [EchoContact], in context: ModelContext) async throws -> GmailSyncResult {
        var token = try await validToken()
        // Capture the mailbox checkpoint before listing messages so anything arriving
        // during this sync is picked up by the next incremental sync.
        let syncStartProfile = try await profile(accessToken: token.accessToken)
        token.email = syncStartProfile.emailAddress
        try tokenStore.save(token)
        let ownEmail = Self.normalize(token.email ?? "")
        var existing = Set(try context.fetch(FetchDescriptor<Interaction>())
            .compactMap(\.externalIdentifier))
        let contactMap = Dictionary(grouping: contacts.compactMap { contact -> (String, EchoContact)? in
            guard let address = contact.emailAddress.map(Self.normalize), !address.isEmpty else { return nil }
            return (address, contact)
        }, by: \.0).mapValues { $0.map(\.1) }
        let referenceResult = try await messageReferences(for: token)
        let references = referenceResult.references

        var imported = 0
        var matchedMessages = 0
        for reference in references {
            let message: GmailMessage
            do {
                message = try await request(
                    path: "users/me/messages/\(reference.id)",
                    query: [
                        URLQueryItem(name: "format", value: "metadata"),
                        URLQueryItem(name: "metadataHeaders", value: "From"),
                        URLQueryItem(name: "metadataHeaders", value: "To"),
                        URLQueryItem(name: "metadataHeaders", value: "Subject"),
                    ],
                    accessToken: token.accessToken
                )
            } catch GmailSyncError.provider(statusCode: 404, message: _) {
                continue
            }
            let headers = (message.payload?.headers ?? []).reduce(into: [String: String]()) {
                $0[$1.name.lowercased()] = $1.value
            }
            let from = Self.emails(in: headers["from"] ?? "")
            let to = Self.emails(in: headers["to"] ?? "")
            let outgoing = message.labelIds?.contains("SENT") == true || from.contains(ownEmail)
            let counterparties = outgoing ? to : from
            let matchedContacts = counterparties
                .flatMap { contactMap[$0] ?? [] }
                .reduce(into: [String: EchoContact]()) { result, contact in
                    result[contact.systemIdentifier] = contact
                }
                .values
            guard !matchedContacts.isEmpty else { continue }
            matchedMessages += 1
            let timestamp = (Double(message.internalDate ?? "") ?? 0) / 1000
            let subject = headers["subject"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = "\(outgoing ? "Sent" : "Received") email\(subject?.isEmpty == false ? ": \(subject!)" : "")"
            for contact in matchedContacts {
                let externalID = "gmail:\(reference.id):\(contact.systemIdentifier)"
                guard !existing.contains(externalID) else { continue }
                let interaction = Interaction(
                    date: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .now,
                    type: .emailed,
                    summary: summary,
                    contact: contact,
                    externalIdentifier: externalID,
                    source: "gmail",
                    isIncoming: !outgoing
                )
                context.insert(interaction)
                existing.insert(externalID)
                if outgoing {
                    contact.lastReachedOut = max(contact.lastReachedOut ?? .distantPast, interaction.date)
                    contact.reachCount += 1
                }
                imported += 1
            }
        }
        try context.save()
        let finishedAt = Date.now
        token.historyID = syncStartProfile.historyID
        token.lastSyncAt = finishedAt
        try tokenStore.save(token)
        return GmailSyncResult(
            importedInteractions: imported,
            messagesScanned: references.count,
            matchedMessages: matchedMessages,
            lastSyncAt: finishedAt,
            wasIncremental: referenceResult.wasIncremental
        )
    }

    func importGoogleContacts(in context: ModelContext) async throws -> GoogleContactImportResult {
        let token = try await validToken()
        guard Self.hasContactScopes(token.grantedScopes) else {
            throw GmailSyncError.provider(
                statusCode: 403,
                message: "Reconnect Google to grant read-only access to saved and other contacts."
            )
        }

        var pageToken: String?
        var people: [GooglePerson] = []
        repeat {
            var components = URLComponents(string: "https://people.googleapis.com/v1/people/me/connections")!
            var query = [
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "sortOrder", value: "FIRST_NAME_ASCENDING"),
                URLQueryItem(
                    name: "personFields",
                    value: "names,emailAddresses,phoneNumbers,organizations,urls,imClients"
                ),
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
            let response: GooglePeopleResponse = try await decode(request)
            people.append(contentsOf: response.connections ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        let savedContactsFound = people.count

        pageToken = nil
        var otherPeople: [GooglePerson] = []
        repeat {
            var components = URLComponents(string: "https://people.googleapis.com/v1/otherContacts")!
            var query = [
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "readMask", value: "names,emailAddresses,phoneNumbers"),
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
            let response: GoogleOtherContactsResponse = try await decode(request)
            otherPeople.append(contentsOf: response.otherContacts ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        people.append(contentsOf: otherPeople)

        var contacts = try context.fetch(FetchDescriptor<EchoContact>())
        var byGoogleID = Dictionary(uniqueKeysWithValues: contacts.map { ($0.systemIdentifier, $0) })
        var byEmail = Dictionary(grouping: contacts.compactMap { contact -> (String, EchoContact)? in
            guard let email = contact.emailAddress.map(Self.normalize), !email.isEmpty else { return nil }
            return (email, contact)
        }, by: \.0).compactMapValues { $0.first?.1 }
        var byPhone = Dictionary(grouping: contacts.compactMap { contact -> (String, EchoContact)? in
            guard let phone = contact.phoneNumber.map(Self.normalizePhone), !phone.isEmpty else { return nil }
            return (phone, contact)
        }, by: \.0).compactMapValues { $0.first?.1 }

        var added = 0
        var updated = 0
        var skipped = 0
        for person in people {
            let googleID = "google:\(person.resourceName)"
            let name = person.names?.first
            let email = person.emailAddresses?.compactMap(\.value).first
            let phone = person.phoneNumbers?.compactMap(\.value).first
            let organization = person.organizations?.first(where: { $0.current == true })
                ?? person.organizations?.first
            let fallbackName = name?.displayName ?? email?.split(separator: "@").first.map(String.init) ?? ""
            let givenName = name?.givenName ?? fallbackName
            let familyName = name?.familyName ?? ""
            guard !givenName.isEmpty || !familyName.isEmpty else {
                skipped += 1
                continue
            }

            let matched = byGoogleID[googleID]
                ?? email.flatMap { byEmail[Self.normalize($0)] }
                ?? phone.flatMap { byPhone[Self.normalizePhone($0)] }

            if let contact = matched {
                let changed = Self.merge(
                    person: person,
                    givenName: givenName,
                    familyName: familyName,
                    email: email,
                    phone: phone,
                    organization: organization,
                    into: contact
                )
                if changed { updated += 1 }
                byGoogleID[googleID] = contact
                if let email { byEmail[Self.normalize(email)] = contact }
                if let phone { byPhone[Self.normalizePhone(phone)] = contact }
            } else {
                let contact = EchoContact(
                    systemIdentifier: googleID,
                    givenName: givenName,
                    familyName: familyName,
                    phoneNumber: phone,
                    emailAddress: email,
                    relationshipDomain: .business,
                    companyName: organization?.name,
                    jobTitle: organization?.title
                )
                _ = Self.mergeSocialProfiles(from: person, into: contact)
                context.insert(contact)
                contacts.append(contact)
                byGoogleID[googleID] = contact
                if let email { byEmail[Self.normalize(email)] = contact }
                if let phone { byPhone[Self.normalizePhone(phone)] = contact }
                added += 1
            }
        }
        try context.save()
        return GoogleContactImportResult(
            added: added,
            updated: updated,
            skipped: skipped,
            savedContactsFound: savedContactsFound,
            otherContactsFound: otherPeople.count
        )
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func authorize(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? GmailSyncError.authorizationFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            guard session.start() else {
                continuation.resume(throwing: GmailSyncError.authorizationFailed)
                return
            }
        }
    }

    private func exchange(code: String, verifier: String, redirectURI: String) async throws -> GmailToken {
        let response: GmailTokenResponse = try await tokenRequest([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        guard let refreshToken = response.refreshToken else { throw GmailSyncError.authorizationFailed }
        return GmailToken(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            expiresAt: .now.addingTimeInterval(response.expiresIn),
            email: nil,
            historyID: nil,
            lastSyncAt: nil,
            grantedScopes: scope
        )
    }

    private func validToken() async throws -> GmailToken {
        guard var token = try tokenStore.read() else { throw GmailSyncError.notConnected }
        guard token.expiresAt <= .now.addingTimeInterval(60) else { return token }
        let response: GmailTokenResponse = try await tokenRequest([
            "client_id": clientID,
            "refresh_token": token.refreshToken,
            "grant_type": "refresh_token",
        ])
        token.accessToken = response.accessToken
        token.expiresAt = .now.addingTimeInterval(response.expiresIn)
        try tokenStore.save(token)
        return token
    }

    private func tokenRequest<T: Decodable>(_ values: [String: String]) async throws -> T {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = values.map {
            "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)"
        }.sorted().joined(separator: "&").data(using: .utf8)
        return try await decode(request)
    }

    private func profile(accessToken: String) async throws -> GmailProfile {
        try await request(
            path: "users/me/profile",
            query: [],
            accessToken: accessToken
        )
    }

    private func messageReferences(
        for token: GmailToken
    ) async throws -> (references: [GmailMessageReference], wasIncremental: Bool) {
        guard let historyID = token.historyID else {
            return (try await recentMessageReferences(accessToken: token.accessToken), false)
        }
        do {
            return (try await incrementalMessageReferences(
                since: historyID,
                accessToken: token.accessToken
            ), true)
        } catch GmailSyncError.provider(statusCode: 404, message: _) {
            return (try await recentMessageReferences(accessToken: token.accessToken), false)
        }
    }

    private func recentMessageReferences(accessToken: String) async throws -> [GmailMessageReference] {
        let response: GmailMessageList = try await request(
            path: "users/me/messages",
            query: [URLQueryItem(name: "maxResults", value: "200")],
            accessToken: accessToken
        )
        return response.messages ?? []
    }

    private func incrementalMessageReferences(
        since historyID: String,
        accessToken: String
    ) async throws -> [GmailMessageReference] {
        var pageToken: String?
        var messageIDs = Set<String>()
        repeat {
            var query = [
                URLQueryItem(name: "startHistoryId", value: historyID),
                URLQueryItem(name: "historyTypes", value: "messageAdded"),
                URLQueryItem(name: "maxResults", value: "500"),
            ]
            if let pageToken {
                query.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let response: GmailHistoryList = try await request(
                path: "users/me/history",
                query: query,
                accessToken: accessToken
            )
            for record in response.history ?? [] {
                for added in record.messagesAdded ?? [] {
                    messageIDs.insert(added.message.id)
                }
            }
            pageToken = response.nextPageToken
        } while pageToken != nil
        return messageIDs.sorted().map(GmailMessageReference.init(id:))
    }

    private func request<T: Decodable>(
        path: String,
        query: [URLQueryItem],
        accessToken: String
    ) async throws -> T {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/\(path)")!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await decode(request)
    }

    private func decode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let providerMessage = try? JSONDecoder().decode(GmailProviderErrorEnvelope.self, from: data)
            let message = providerMessage?.error.message ?? "Gmail request failed."
            throw GmailSyncError.provider(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded
    }

    private static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func hasContactScopes(_ scopes: String?) -> Bool {
        guard let scopes else { return false }
        return scopes.contains("contacts.readonly") && scopes.contains("contacts.other.readonly")
    }

    private static func hasSendScope(_ scopes: String?) -> Bool {
        scopes?.contains("gmail.send") == true
    }

    private static func normalizePhone(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }

    private static func merge(
        person: GooglePerson,
        givenName: String,
        familyName: String,
        email: String?,
        phone: String?,
        organization: GoogleOrganization?,
        into contact: EchoContact
    ) -> Bool {
        var changed = false
        func assign(_ value: String?, to keyPath: ReferenceWritableKeyPath<EchoContact, String?>) {
            guard let value, !value.isEmpty, contact[keyPath: keyPath] != value else { return }
            contact[keyPath: keyPath] = value
            changed = true
        }
        if !givenName.isEmpty, contact.givenName != givenName {
            contact.givenName = givenName
            changed = true
        }
        if !familyName.isEmpty, contact.familyName != familyName {
            contact.familyName = familyName
            changed = true
        }
        assign(email, to: \.emailAddress)
        assign(phone, to: \.phoneNumber)
        assign(organization?.name, to: \.companyName)
        assign(organization?.title, to: \.jobTitle)
        return mergeSocialProfiles(from: person, into: contact) || changed
    }

    private static func mergeSocialProfiles(from person: GooglePerson, into contact: EchoContact) -> Bool {
        var changed = false
        for value in person.urls?.compactMap(\.value) ?? [] {
            guard let platform = socialPlatform(for: value) else { continue }
            let identifier = SocialMessagingService.normalizedIdentifier(value, for: platform)
            guard !identifier.isEmpty, contact.socialIdentifier(for: platform) != identifier else { continue }
            contact.setSocialIdentifier(identifier, for: platform)
            changed = true
        }
        for client in person.imClients ?? [] {
            guard let username = client.username,
                  let platform = socialPlatform(for: [client.protocolName, client.formattedProtocol].compactMap { $0 }.joined(separator: " "))
            else { continue }
            let identifier = SocialMessagingService.normalizedIdentifier(username, for: platform)
            guard !identifier.isEmpty, contact.socialIdentifier(for: platform) != identifier else { continue }
            contact.setSocialIdentifier(identifier, for: platform)
            changed = true
        }
        return changed
    }

    private static func socialPlatform(for value: String) -> SocialPlatform? {
        let lower = value.lowercased()
        if lower.contains("whatsapp") || lower.contains("wa.me") { return .whatsapp }
        if lower.contains("telegram") || lower.contains("t.me") { return .telegram }
        if lower.contains("instagram") { return .instagram }
        if lower.contains("facebook") || lower.contains("m.me") { return .facebook }
        if lower.contains("twitter") || lower.contains("x.com") { return .x }
        if lower.contains("linkedin") { return .linkedin }
        if lower.contains("reddit") { return .reddit }
        if lower.contains("discord") { return .discord }
        return nil
    }

    static func emails(in value: String) -> Set<String> {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(value.startIndex..., in: value)
        return Set((regex?.matches(in: value, range: range) ?? []).compactMap {
            Range($0.range, in: value).map { normalize(String(value[$0])) }
        })
    }
}

private struct GmailTokenStore {
    private let service = "com.bambi2008.Echo.gmail"
    private let account = "oauth-token"

    func save(_ token: GmailToken) throws {
        let data = try JSONEncoder().encode(token)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw GmailSyncError.authorizationFailed
            }
        } else if status != errSecSuccess {
            throw GmailSyncError.authorizationFailed
        }
    }

    func read() throws -> GmailToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw GmailSyncError.authorizationFailed
        }
        return try JSONDecoder().decode(GmailToken.self, from: data)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GmailSyncError.authorizationFailed
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}
