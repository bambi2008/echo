import Foundation
import NaturalLanguage

struct RecallCandidate: Identifiable {
    let contact: EchoContact
    let score: Int
    let matchedKeywords: [String]
    let evidence: [String]

    var id: String { contact.systemIdentifier }

    var localReason: String {
        guard !evidence.isEmpty else { return "Has related saved context" }
        return "Matches " + evidence.prefix(3).joined(separator: ", ")
    }
}

enum RecallSearchEngine {
    static func search(
        description: String,
        contacts: [EchoContact],
        limit: Int = 8,
        now: Date = .now
    ) -> [RecallCandidate] {
        let keywords = queryKeywords(from: description, now: now)
        let queryPhonetics = phoneticSyllables(from: description)
        guard !keywords.isEmpty || !queryPhonetics.isEmpty else { return [] }

        return contacts.compactMap {
            candidate(for: $0, keywords: keywords, queryPhonetics: queryPhonetics)
        }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.matchedKeywords.count != $1.matchedKeywords.count {
                    return $0.matchedKeywords.count > $1.matchedKeywords.count
                }
                return $0.contact.fullName.localizedStandardCompare($1.contact.fullName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    static func queryKeywords(from description: String, now: Date = .now) -> [String] {
        let normalized = normalize(description)
        guard !normalized.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalized
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: normalized.startIndex..<normalized.endIndex) { range, _ in
            let token = String(normalized[range]).trimmingCharacters(in: .punctuationCharacters)
            if isUseful(token), !tokens.contains(token) {
                tokens.append(token)
            }
            return true
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        if normalized.contains("去年") || normalized.contains("last year") {
            tokens.append(String(year - 1))
        }
        if normalized.contains("今年") || normalized.contains("this year") {
            tokens.append(String(year))
        }
        if normalized.contains("前年") {
            tokens.append(String(year - 2))
        }
        for (clue, equivalents) in bilingualClues where normalized.contains(clue) {
            for equivalent in equivalents where !tokens.contains(equivalent) {
                tokens.append(equivalent)
            }
        }
        return Array(tokens.prefix(20))
    }

    private static func candidate(
        for contact: EchoContact,
        keywords: [String],
        queryPhonetics: [String]
    ) -> RecallCandidate? {
        let fields = searchableFields(for: contact)
        var score = 0
        var matchedKeywords: [String] = []
        var evidence: [String] = []

        for keyword in keywords {
            var bestMatch: SearchField?
            for field in fields where field.value.contains(keyword) {
                if bestMatch == nil || field.weight > bestMatch!.weight {
                    bestMatch = field
                }
            }
            guard let bestMatch else { continue }
            score += bestMatch.weight
            matchedKeywords.append(keyword)
            if !evidence.contains(bestMatch.label) {
                evidence.append(bestMatch.label)
            }
        }

        if let phoneticScore = phoneticNameScore(for: contact, queryPhonetics: queryPhonetics),
           !evidence.contains("a partial name") {
            score += phoneticScore
            matchedKeywords.append("similar-sounding name")
            evidence.append("a similar-sounding name")
        }

        guard score > 0 else { return nil }
        score += min(contact.notes.count + contact.interactions.count, 6)
        return RecallCandidate(
            contact: contact,
            score: score,
            matchedKeywords: matchedKeywords,
            evidence: evidence
        )
    }

    private static func searchableFields(for contact: EchoContact) -> [SearchField] {
        var fields = [
            SearchField(value: contact.fullName, label: "a partial name", weight: 12),
            SearchField(value: contact.companyName ?? "", label: "company", weight: 10),
            SearchField(value: contact.jobTitle ?? "", label: "role", weight: 9),
            SearchField(
                value: contact.tags.joined(separator: " "),
                label: "identity or industry",
                weight: 9
            ),
            SearchField(
                value: contact.relationshipDomain.title,
                label: "relationship type",
                weight: 5
            ),
        ]

        fields += contact.notes.map {
            SearchField(
                value: "\($0.content) \(dateClues(for: $0.createdAt))",
                label: "a saved note",
                weight: 8
            )
        }
        fields += contact.interactions.map {
            SearchField(
                value: "\($0.summary) \($0.type.title) \(dateClues(for: $0.date))",
                label: $0.sourceRawValue == "gmail" ? "an email subject" : "interaction history",
                weight: 7
            )
        }
        return fields
    }

    private static func dateClues(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year.map(String.init) ?? ""
        let month = components.month.map { "\($0)月" } ?? ""
        let englishMonth = date.formatted(.dateTime.month(.wide))
        return "\(year) \(month) \(englishMonth)"
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func phoneticNameScore(
        for contact: EchoContact,
        queryPhonetics: [String]
    ) -> Int? {
        let nameVariants = phoneticNameVariants(for: contact)
        guard !nameVariants.isEmpty else { return nil }

        for variant in nameVariants where containsSequence(variant, in: queryPhonetics) {
            return 16
        }

        var bestSimilarity = 0.0
        for variant in nameVariants where variant.count >= 2 && queryPhonetics.count >= variant.count {
            for start in 0...(queryPhonetics.count - variant.count) {
                let window = Array(queryPhonetics[start..<(start + variant.count)])
                let similarities = zip(variant, window).map { syllableSimilarity($0, $1) }
                let exactSyllables = zip(variant, window).filter { $0.0 == $0.1 }.count
                let average = similarities.reduce(0, +) / Double(similarities.count)
                if exactSyllables >= max(1, variant.count - 1) {
                    bestSimilarity = max(bestSimilarity, average)
                }
            }
        }
        return bestSimilarity >= 0.82 ? 11 : nil
    }

    private static func phoneticNameVariants(for contact: EchoContact) -> [[String]] {
        guard containsHanCharacters(contact.fullName) else { return [] }
        let values = [
            contact.fullName,
            [contact.familyName, contact.givenName].filter { !$0.isEmpty }.joined(separator: " "),
            contact.givenName.count >= 2 ? contact.givenName : "",
            contact.familyName.count >= 2 ? contact.familyName : "",
        ]
        var variants: [[String]] = []
        for value in values where !value.isEmpty {
            let syllables = phoneticSyllables(from: value)
            guard syllables.count >= 2, !variants.contains(syllables) else { continue }
            variants.append(syllables)
            if syllables.count >= 3 {
                let withoutFirst = Array(syllables.dropFirst())
                if !variants.contains(withoutFirst) { variants.append(withoutFirst) }
            }
        }
        return variants
    }

    private static func phoneticSyllables(from value: String) -> [String] {
        let latin = value.applyingTransform(.toLatin, reverse: false) ?? value
        let folded = latin
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func containsSequence(_ sequence: [String], in values: [String]) -> Bool {
        guard !sequence.isEmpty, values.count >= sequence.count else { return false }
        for start in 0...(values.count - sequence.count) {
            if Array(values[start..<(start + sequence.count)]) == sequence { return true }
        }
        return false
    }

    private static func syllableSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let longest = max(lhs.count, rhs.count)
        guard longest > 0 else { return 1 }
        return 1 - (Double(editDistance(lhs, rhs)) / Double(longest))
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)
        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            for (rightIndex, rightCharacter) in right.enumerated() {
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                current.append(min(insertion, min(deletion, substitution)))
            }
            previous = current
        }
        return previous.last ?? left.count
    }

    private static func containsHanCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private static func isUseful(_ token: String) -> Bool {
        guard token.count >= 2 || token.allSatisfy(\.isNumber) else { return false }
        return !stopWords.contains(token)
    }

    private static let stopWords: Set<String> = [
        "一个", "一些", "那个", "这个", "的人", "帮我", "找到", "想找", "认识",
        "好像", "可能", "记得", "忘了", "名字", "联系", "突然", "应该", "对方",
        "someone", "person", "whose", "with", "from", "that", "this", "their",
        "name", "remember", "forgot", "find", "met", "maybe", "about",
    ]

    private static let bilingualClues: [String: [String]] = [
        "保险": ["insurance", "policy", "coverage"],
        "金融": ["finance", "financial", "wealth", "bank"],
        "同事": ["colleague", "coworker"],
        "客户": ["client", "customer"],
        "企业": ["enterprise", "business", "company"],
        "活动": ["event", "conference"],
        "介绍": ["introduced", "introduction", "referred"],
        "续保": ["renewal", "renew", "policy"],
        "邮件": ["email", "emailed"],
        "投资": ["investor", "investment", "venture"],
        "合作": ["partner", "partnership", "collaboration"],
        "导师": ["mentor", "advisor", "professor"],
        "朋友": ["friend"],
        "邻居": ["neighbor"],
        "家人": ["family"],
        "设计": ["design", "designer"],
        "招聘": ["recruiting", "recruiter", "hiring"],
        "产品": ["product"],
        "销售": ["sales"],
        "律师": ["attorney", "legal", "lawyer"],
        "医生": ["physician", "doctor", "healthcare"],
        "老师": ["professor", "teacher", "education"],
        "房产": ["real estate", "property", "broker"],
    ]

    private struct SearchField {
        let value: String
        let label: String
        let weight: Int

        init(value: String, label: String, weight: Int) {
            self.value = RecallSearchEngine.normalize(value)
            self.label = label
            self.weight = weight
        }
    }
}
