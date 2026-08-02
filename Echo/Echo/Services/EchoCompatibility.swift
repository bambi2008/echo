import SwiftUI
import StoreKit
extension EchoTheme {
    static var accentColor: Color { accent }
    static var cardGradient: LinearGradient { LinearGradient(colors: [bgCard, bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var cardRadius: CGFloat { radius16 }
    static var backgroundGradient: LinearGradient { LinearGradient(colors: [bgPrimary, Color(red: 0.02, green: 0.025, blue: 0.04)], startPoint: .top, endPoint: .bottom) }
    static var darkBackground: Color { bgPrimary }
    static var cardBackground: Color { bgCard }
    static var gradient: LinearGradient { LinearGradient(colors: [accent, Color(hex: "00F5FF")], startPoint: .leading, endPoint: .trailing) }
    static var sectionFont: Font { .system(size: 16, weight: .bold) }
    static var captionFont: Font { .system(size: 12) }
    static var titleFont: Font { .system(size: 22, weight: .bold, design: .rounded) }
    static var bodyFont: Font { .system(size: 15) }
}
extension Color { init(hex: String) { let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v); let r, g, b: UInt64; (r, g, b) = (v >> 16, v >> 8 & 0xFF, v & 0xFF); self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) } }
extension StreakManager { static let shared = StreakManager(); func calculateStreak(from dates: [Date]) -> Int { let cal = Calendar.current; let sorted = Set(dates.map { cal.startOfDay(for: $0) }).sorted(by: >); guard !sorted.isEmpty else { return 0 }; var streak = 0; var check = cal.startOfDay(for: Date()); if sorted.first == check { while sorted.contains(check) { streak += 1; check = cal.date(byAdding: .day, value: -1, to: check)! } } else if let y = cal.date(byAdding: .day, value: -1, to: check), sorted.first == y { check = y; while sorted.contains(check) { streak += 1; check = cal.date(byAdding: .day, value: -1, to: check)! } }; return streak } }
extension EchoHaptics { static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }; static func confirm() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8) }; static func impact() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }; static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }; static func celebrate() { let g = UIImpactFeedbackGenerator(style: .heavy); g.impactOccurred(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { g.impactOccurred(intensity: 0.6) }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { g.impactOccurred(intensity: 0.3) } }; static func wave() { let g = UIImpactFeedbackGenerator(style: .soft); for i in 0..<3 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) { g.impactOccurred(intensity: 0.3 + Double(i) * 0.2) } } } }
extension AIEngine { static func smartSearch(query: String, in contacts: [EchoContact]) -> [(EchoContact, Double)] { let q = query.lowercased(); return contacts.filter { c in c.fullName.lowercased().contains(q) || c.givenName.lowercased().contains(q) || (c.companyName?.lowercased().contains(q) ?? false) || c.notes.contains { $0.content.lowercased().contains(q) } || c.interactions.contains { $0.note.lowercased().contains(q) } }.map { ($0, 1.0) } } }
extension TrialManager { var daysRemaining: Int { trialDaysRemaining } }
struct SurveyResult { var relationshipCount: Int; var biggestChallenge: String; var preferredFrequency: String; var motivator: String }
struct AIChatResponse { let text: String; let cards: [ChatMessage.ChatCard] }
struct AIChatEngine {
    static func respond(to input: String, contacts: [EchoContact]) -> AIChatResponse {
        let l = input.lowercased()
        if l.contains("谁") || l.contains("who") || l.contains("联系") { let sorted = contacts.sorted { AIEngine.healthScore(for: $0).score < AIEngine.healthScore(for: $1).score }; if let top = sorted.first { let gap = Int(Date().timeIntervalSince(top.lastReachedOut ?? Date()) / 86400); let card = ChatMessage.ChatCard(type: .contactCard, contact: top, title: top.givenName, detail: "\(gap) 天未联系 — 健康分 \(AIEngine.healthScore(for: top).score)", score: AIEngine.healthScore(for: top).score); return AIChatResponse(text: "建议你先联系 \(top.givenName)，已经 \(gap) 天了。", cards: [card]) } }
        if l.contains("健康") || l.contains("health") || l.contains("怎么样") { let h = contacts.filter { AIEngine.healthScore(for: $0).level == .thriving || AIEngine.healthScore(for: $0).level == .stable }.count; let r = contacts.filter { AIEngine.healthScore(for: $0).level == .fading || AIEngine.healthScore(for: $0).level == .critical }.count; return AIChatResponse(text: "\(h) 段关系健康，\(r) 段需要关注。", cards: []) }
        if l.contains("streak") || l.contains("连续") { let s = StreakManager.shared.calculateStreak(from: contacts.flatMap { $0.interactions }.map { $0.date }); return AIChatResponse(text: s > 0 ? "你已经连续 \(s) 天联系了某人！" : "Streak 断了 — 今天重新开始吧", cards: []) }
        if l.contains("总结") || l.contains("summary") || l.contains("周报") { let total = contacts.flatMap { $0.interactions }.count; let healthy = contacts.filter { AIEngine.healthScore(for: $0).level == .thriving }.count; return AIChatResponse(text: "本周总结：\(total) 次互动，\(healthy) 段关系蓬勃发展。", cards: []) }
        if l.contains("写") || l.contains("消息") || l.contains("message") { if let c = contacts.first { let gap = Int(Date().timeIntervalSince(c.lastReachedOut ?? Date()) / 86400); let msg = gap > 30 ? "Hey \(c.givenName), been a while! Hope you're doing well." : "Hi \(c.givenName), just thinking of you!"; return AIChatResponse(text: msg, cards: []) } }
        return AIChatResponse(text: "嘿！我在这里帮你维护关系。可以问我\"今天该联系谁\"、\"关系健康状况\"或者\"本周总结\"。", cards: [])
    }
}