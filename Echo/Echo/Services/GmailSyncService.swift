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

private struct GmailToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String?
    var historyID: String?
    var lastSyncAt: Date?
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

enum GmailSyncError: LocalizedError {
    case notConnected
    case invalidConfiguration
    case authorizationFailed
    case provider(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect Gmail before syncing."
        case .invalidConfiguration: "Gmail OAuth is not configured correctly."
        case .authorizationFailed: "Google authorization did not complete."
        case .provider(let statusCode, let message):
            switch statusCode {
            case 401:
                "Google access has expired. Disconnect Gmail and connect it again."
            case 403:
                "Google did not allow this Gmail request. Check the Gmail permission and try again."
            case 429:
                "Gmail is temporarily rate-limiting Echo. Wait a moment and try again."
            default:
                message
            }
        }
    }
}

@MainActor
final class GmailSyncService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GmailSyncService()

    private let clientID = "584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5.apps.googleusercontent.com"
    private let callbackScheme = "com.googleusercontent.apps.584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5"
    private let scope = "https://www.googleapis.com/auth/gmail.metadata"
    private let tokenStore = GmailTokenStore()
    private var authenticationSession: ASWebAuthenticationSession?

    func status() -> GmailConnectionStatus? {
        guard let token = try? tokenStore.read(), let email = token.email else { return nil }
        return GmailConnectionStatus(
            email: email,
            expiresAt: token.expiresAt,
            lastSyncAt: token.lastSyncAt
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
            URLQueryItem(name: "prompt", value: "consent"),
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
            lastSyncAt: token.lastSyncAt
        )
    }

    func disconnect() throws {
        try tokenStore.delete()
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
            lastSyncAt: nil
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

    private static func emails(in value: String) -> Set<String> {
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
