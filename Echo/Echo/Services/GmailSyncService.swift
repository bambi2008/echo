import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftData
import UIKit

struct GmailConnectionStatus {
    let email: String
    let expiresAt: Date
}

private struct GmailToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String?
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
}

private struct GmailMessageList: Decodable {
    let messages: [GmailMessageReference]?
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

enum GmailSyncError: LocalizedError {
    case notConnected
    case invalidConfiguration
    case authorizationFailed
    case provider(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect Gmail before syncing."
        case .invalidConfiguration: "Gmail OAuth is not configured correctly."
        case .authorizationFailed: "Google authorization did not complete."
        case .provider(let message): message
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
        return GmailConnectionStatus(email: email, expiresAt: token.expiresAt)
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
        token.email = try await profileEmail(accessToken: token.accessToken)
        try tokenStore.save(token)
        return GmailConnectionStatus(email: token.email ?? "", expiresAt: token.expiresAt)
    }

    func disconnect() throws {
        try tokenStore.delete()
    }

    func sync(contacts: [EchoContact], in context: ModelContext) async throws -> Int {
        var token = try await validToken()
        if token.email == nil {
            token.email = try await profileEmail(accessToken: token.accessToken)
            try tokenStore.save(token)
        }
        let ownEmail = Self.normalize(token.email ?? "")
        var existing = Set(try context.fetch(FetchDescriptor<Interaction>())
            .compactMap(\.externalIdentifier))
        let contactMap = Dictionary(grouping: contacts.compactMap { contact -> (String, EchoContact)? in
            guard let address = contact.emailAddress.map(Self.normalize), !address.isEmpty else { return nil }
            return (address, contact)
        }, by: \.0).mapValues { $0.map(\.1) }
        let references: GmailMessageList = try await request(
            path: "users/me/messages",
            query: [URLQueryItem(name: "maxResults", value: "100")],
            accessToken: token.accessToken
        )

        var imported = 0
        for reference in references.messages ?? [] {
            let message: GmailMessage = try await request(
                path: "users/me/messages/\(reference.id)",
                query: [
                    URLQueryItem(name: "format", value: "metadata"),
                    URLQueryItem(name: "metadataHeaders", value: "From"),
                    URLQueryItem(name: "metadataHeaders", value: "To"),
                    URLQueryItem(name: "metadataHeaders", value: "Subject"),
                ],
                accessToken: token.accessToken
            )
            let headers = Dictionary(uniqueKeysWithValues: (message.payload?.headers ?? []).map {
                ($0.name.lowercased(), $0.value)
            })
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
        return imported
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
            email: nil
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

    private func profileEmail(accessToken: String) async throws -> String {
        let profile: GmailProfile = try await request(
            path: "users/me/profile",
            query: [],
            accessToken: accessToken
        )
        return profile.emailAddress
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
            let message = String(data: data, encoding: .utf8) ?? "Gmail request failed."
            throw GmailSyncError.provider(message)
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
