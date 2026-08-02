import Foundation
struct EchoCompanion {
    static let personality = "You are Echo — a warm, caring companion. You talk like a close friend, not a robot. You're encouraging but not preachy. You have subtle humor. You're direct when needed but always kind."
    static func response(for input: String, contacts: [EchoContact]) -> String {
        let l = input.lowercased()
        if l.contains("谁") || l.contains("contact") || l.contains("reach") || l.contains("联系") { return whoToReach(contacts) }
        if l.contains("health") || l.contains("健康") || l.contains("怎么样") { return health(contacts) }
        if l.contains("suggest") || l.contains("建议") || l.contains("tip") || l.contains("help") { return suggestion() }
        if l.contains("streak") || l.contains("连续") { return streak(contacts) }
        return `default`(contacts)
    }
    private static func whoToReach(_ contacts: [EchoContact]) -> String {
        let sorted = contacts.sorted { AIEngine.healthScore(for: $0).score < AIEngine.healthScore(for: $1).score }; guard let top = sorted.first else { return "你还没有联系人呢，先导入一些吧" }
        let gap = Int(Date().timeIntervalSince(top.lastReachedOut ?? Date()) / 86400)
        if gap > 60 { return "说实话，\(top.givenName) 那边已经 \(gap) 天没动静了 关系有点凉了，但还来得及。要不要我帮你写条消息？" }
        if gap > 14 { return "\(top.givenName) 大概 \(gap) 天没联系了。不是太久，但提前打个招呼总比等着关系变淡好。" }
        return "其实你做得不错！最近联系的人都挺好的。如果想继续加分，可以给 \(top.givenName) 发个有趣的链接"
    }
    private static func health(_ contacts: [EchoContact]) -> String {
        let h = contacts.filter { AIEngine.healthScore(for: $0).level == .thriving || AIEngine.healthScore(for: $0).level == .stable }.count; let r = contacts.filter { AIEngine.healthScore(for: $0).level == .fading || AIEngine.healthScore(for: $0).level == .critical }.count
        if r == 0 { return "整体很不错 \(h) 段关系都在健康状态。继续保持这个节奏，你是个靠谱的人。" }
        if r <= 2 { return "大部分关系都还行，但 \(r) 个需要关注。别等到关系断了才想起来联系 — 现在发条消息就行。" }
        return "说实话，有点警报了 \(r) 段关系都在淡化。建议今天就处理最紧急的 2-3 个。"
    }
    private static func suggestion() -> String {
        let tips = ["给很久没联系的人发个你最近看到的有趣链接。\"看到这个想起你了\" 就够了。", "早上通勤时联系一个人 — 那是你最清醒的时候。", "别只发文字。一条 10 秒的语音消息比打字更温暖。", "记住：关系的质量比频率重要。每月一次有深度的对话，比每天一次早安强 10 倍。"]
        return tips.randomElement() ?? tips[0]
    }
    private static func streak(_ contacts: [EchoContact]) -> String {
        let s = StreakManager.shared.calculateStreak(from: contacts.flatMap { $0.interactions }.map { $0.date })
        if s == 0 { return "你的 streak 断了 — 但没关系，今天就是重新开始的好日子" }
        if s < 7 { return "你已经连续 \(s) 天了！刚开始最难的，继续保持" }
        if s < 30 { return "\(s) 天连续！你已经在养成习惯了，继续加油" }
        return "\(s) 天！你已经是关系维护大师了。说实话，这很厉害。"
    }
    private static func `default`(_ contacts: [EchoContact]) -> String {
        let r = contacts.filter { AIEngine.healthScore(for: $0).level == .critical || AIEngine.healthScore(for: $0).level == .fading }.count
        if r > 0 { return "嘿！我在这里帮你维护关系。目前有 \(r) 段关系需要关注。想让我帮你看看该先联系谁吗？" }
        return "嘿！有什么我能帮的？可以问我\"该联系谁\"、\"关系健康状况\"或者给我一个话题我来建议。"
    }
}