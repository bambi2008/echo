import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct GoogleIdentity {
    let identifier: String
    let email: String
    let name: String
}

private struct GoogleIdentityTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct GoogleIdentityProfile: Decodable {
    let sub: String
    let email: String
    let name: String?
}

enum GoogleIdentityError: LocalizedError {
    case invalidConfiguration
    case authorizationFailed
    case provider(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Google sign-in is not configured correctly."
        case .authorizationFailed:
            "Google sign-in was not completed."
        case .provider(let message):
            message
        }
    }
}

@MainActor
final class GoogleIdentityService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleIdentityService()

    private let clientID = "584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5.apps.googleusercontent.com"
    private let callbackScheme = "com.googleusercontent.apps.584656353169-ih6dd4dth5lo17aigac05k5l5qju6nr5"
    private var authenticationSession: ASWebAuthenticationSession?

    func signIn() async throws -> GoogleIdentity {
        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let redirectURI = "\(callbackScheme):/oauthredirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizationURL = components.url else {
            throw GoogleIdentityError.invalidConfiguration
        }

        let callbackURL = try await authorize(url: authorizationURL)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw GoogleIdentityError.authorizationFailed
        }

        let token = try await exchange(code: code, verifier: verifier, redirectURI: redirectURI)
        let profile = try await profile(accessToken: token.accessToken)
        return GoogleIdentity(
            identifier: profile.sub,
            email: profile.email,
            name: profile.name ?? profile.email
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
                    continuation.resume(throwing: error ?? GoogleIdentityError.authorizationFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            guard session.start() else {
                continuation.resume(throwing: GoogleIdentityError.authorizationFailed)
                return
            }
        }
    }

    private func exchange(
        code: String,
        verifier: String,
        redirectURI: String
    ) async throws -> GoogleIdentityTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        return try await decode(request)
    }

    private func profile(accessToken: String) async throws -> GoogleIdentityProfile {
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await decode(request)
    }

    private func decode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Google sign-in failed."
            throw GoogleIdentityError.provider(message: message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
