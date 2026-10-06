import Foundation

/// Builds Gmail compose links without sending anything automatically.
/// The Gmail app receives the reviewed recipient, subject, and body only when
/// the user taps Echo's final outreach button.
enum GmailComposeService {
    static func appURL(recipient: String, subject: String, body: String) -> URL? {
        components(
            scheme: "googlegmail",
            host: "co",
            recipient: recipient,
            subject: subject,
            body: body
        )?.url
    }

    static func webURL(recipient: String, subject: String, body: String) -> URL? {
        var components = URLComponents(string: "https://mail.google.com/mail/u/0/")
        components?.queryItems = [
            URLQueryItem(name: "view", value: "cm"),
            URLQueryItem(name: "fs", value: "1"),
            URLQueryItem(name: "to", value: recipient),
            URLQueryItem(name: "su", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components?.url
    }

    private static func components(
        scheme: String,
        host: String,
        recipient: String,
        subject: String,
        body: String
    ) -> URLComponents? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "to", value: recipient),
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components
    }
}
