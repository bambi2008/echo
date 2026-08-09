import Foundation

enum PhoneCallService {
    static func destination(for phoneNumber: String) -> URL? {
        var normalized = ""
        for character in phoneNumber {
            if character.isNumber {
                normalized.append(character)
            } else if character == "+", normalized.isEmpty {
                normalized.append(character)
            }
        }
        let digitCount = normalized.filter(\.isNumber).count
        guard digitCount >= 3 else { return nil }
        return URL(string: "tel:\(normalized)")
    }
}
