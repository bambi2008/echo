import Foundation
extension AIEngine {
    static func generateSmartMessages(for contact: EchoContact, tone: MessageTone, gapDays: Int) -> [String] {
        let name = contact.givenName
        let templates: [(MessageTone, [String])] = [
            (.warm, [
                "Hey \(name), I was just thinking about you and realized it's been \(gapDays) days since we last talked. I miss our conversations. How have you been?",
                "Hi \(name), something reminded me of you today and it made me smile. I'd love to catch up and hear what's new in your life. Coffee soon?",
                "Dear \(name), I hope you're doing well. I realized I've been terrible at staying in touch, but you've been on my mind. Let's find time to talk soon."
            ]),
            (.casual, [
                "Yo \(name)! Long time no see. What's new? Let's grab a drink or something.",
                "Hey \(name), it's been a minute. Just checking in — hope life's treating you well. Hit me up when you're free!",
                "\(name)! Been way too long. I was just telling someone about that time we \(gapDays > 90 ? "hung out ages ago" : "caught up recently") and figured I should reach out. What's the move these days?"
            ]),
            (.professional, [
                "Hi \(name), I hope this message finds you well. I wanted to reconnect as it's been some time since our last conversation. I'd love to hear about your recent work and share updates on mine. Would you be available for a brief call next week?",
                "Dear \(name), I trust you're doing well. It occurred to me that we haven't spoken in \(gapDays) days, and I'd like to change that. Let me know if you'd be open to catching up over coffee or a call.",
                "Hello \(name), I hope things are going well on your end. I'd like to reconnect and learn about any new developments since we last spoke. Please let me know a convenient time to talk."
            ])
        ]
        for (t, msgs) in templates { if t == tone { return msgs } }
        return ["Hey \(name), it's been a while! Just wanted to reach out and see how you're doing."]
    }
}