import Foundation

/// An immutable, request-scoped mapping. Original identifiers never need to be
/// persisted or sent to the provider, and aliases can be restored locally.
public struct AIPrivacyContext: Sendable, Equatable {
    public let replacements: [AIPrivacyReplacement]

    public init(people: [String] = [], companies: [String] = []) {
        var values: [AIPrivacyReplacement] = []
        var seen = Set<String>()

        var personIndex = 0
        for name in people {
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized.lowercased()).inserted else { continue }
            values.append(.init(original: normalized, alias: "Person \(Self.label(personIndex))"))
            personIndex += 1
        }
        var companyIndex = 0
        for company in companies {
            let normalized = company.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized.lowercased()).inserted else { continue }
            values.append(.init(original: normalized, alias: "Company \(Self.label(companyIndex))"))
            companyIndex += 1
        }

        replacements = values.sorted { $0.original.count > $1.original.count }
    }

    public init(replacements: [AIPrivacyReplacement]) {
        self.replacements = replacements
            .filter { !$0.original.isEmpty && !$0.alias.isEmpty }
            .sorted { $0.original.count > $1.original.count }
    }

    /// Replaces known names and companies, then masks common email addresses
    /// and phone numbers that were not explicitly included in the mapping.
    public func anonymize(_ text: String) -> String {
        var result = text
        for replacement in replacements {
            result = result.replacingOccurrences(
                of: replacement.original,
                with: replacement.alias,
                options: [.caseInsensitive]
            )
        }
        result = Self.replacingMatches(
            in: result,
            pattern: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            template: "[EMAIL]",
            options: [.caseInsensitive]
        )
        result = Self.redactingPhoneNumbers(in: result)
        return result
    }

    /// Restores only aliases created from the explicit mapping. Generic email
    /// and phone redactions intentionally remain redacted.
    public func restoreAliases(in text: String) -> String {
        var result = text
        for replacement in replacements.sorted(by: { $0.alias.count > $1.alias.count }) {
            result = result.replacingOccurrences(
                of: replacement.alias,
                with: replacement.original,
                options: [.caseInsensitive]
            )
        }
        return result
    }

    public func alias(for original: String) -> String? {
        replacements.first {
            $0.original.compare(original, options: .caseInsensitive) == .orderedSame
        }?.alias
    }

    private static func label(_ index: Int) -> String {
        guard index < 26 else { return String(index + 1) }
        return String(UnicodeScalar(65 + index)!)
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        template: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: template
        )
    }

    private static func redactingPhoneNumbers(in text: String) -> String {
        let pattern = #"(?<![\w-])(?:\+?\d[\d\s().-]{7,}\d)(?![\w-])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let candidate = result[range]
            let digitCount = candidate.filter(\.isNumber).count
            guard digitCount >= 10 else { continue }
            result.replaceSubrange(range, with: "[PHONE]")
        }
        return result
    }
}

public struct AIPrivacyReplacement: Sendable, Equatable {
    public let original: String
    public let alias: String

    public init(original: String, alias: String) {
        self.original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        self.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
