import SwiftUI
import SwiftData

struct AIChatView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }) var contacts: [EchoContact]
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if messages.isEmpty { welcomeSection }
                        ForEach(messages) { msg in ChatBubble(message: msg).id(msg.id) }
                        if isThinking { ThinkingBubble().id("thinking") }
                    }.padding(.horizontal, 16).padding(.top, 16)
                }
                .onChange(of: messages.count) { _ in withAnimation { proxy.scrollTo(messages.last?.id ?? "thinking", anchor: .bottom) } }
            }
            if messages.count <= 2 { quickQuestions.transition(.move(edge: .bottom).combined(with: .opacity)) }
            inputBar
        }
        .background(EchoTheme.darkBackground).navigationTitle("Echo AI").navigationBarTitleDisplayMode(.inline)
    }
    var welcomeSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(EchoTheme.gradient)
            Text("你好，我是 Echo AI").font(EchoTheme.titleFont)
            Text("你的私人关系智能助手\n问我任何关于你人际关系的问题").font(EchoTheme.bodyFont).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.top, 40)
    }
    var quickQuestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<suggestedQuestions.count) { i in
                    Button { sendQuestion(suggestedQuestions[i]) } label: {
                        Text(suggestedQuestions[i]).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                            .padding(.horizontal, 14).padding(.vertical, 8).background(EchoTheme.cardBackground).clipShape(Capsule())
                            .overlay(Capsule().stroke(EchoTheme.accentColor.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16).padding(.bottom, 8)
        }
    }
    var inputBar: some View {
        HStack(spacing: 10) {
            TextField("问我任何问题...", text: $inputText, axis: .vertical)
                .font(.system(size: 15)).focused($inputFocused).lineLimit(1...4)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(EchoTheme.accentColor.opacity(0.2), lineWidth: 1))
            Button { sendQuestion(inputText) } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? AnyShapeStyle(.gray.opacity(0.4)) : AnyShapeStyle(EchoTheme.gradient))
            }.disabled(inputText.isEmpty).buttonStyle(.plain)
        }.padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
    }
    var suggestedQuestions: [String] {
        ["今天该联系谁？", "我和谁正在失去联系？", "本周关系总结", "帮我写条消息", "谁的关系健康分最低？"] + (contacts.isEmpty ? [] : [contacts[0].givenName + "的关系怎么样？"])
    }
    func sendQuestion(_ q: String) {
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        messages.append(ChatMessage(role: .user, text: q)); inputText = ""; isThinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let response = AIChatEngine.respond(to: q, contacts: contacts)
            messages.append(ChatMessage(role: .assistant, text: response.text, cards: response.cards)); isThinking = false
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID(); let role: Role; var text: String; var cards: [ChatCard]?
    enum Role { case user, assistant }
    struct ChatCard: Identifiable { let id = UUID(); let type: CardType; let contact: EchoContact?; let title: String; let detail: String; let score: Int?; enum CardType { case contactCard, healthCard, suggestionCard, summaryCard } }
}

struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 50) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .assistant { HStack(spacing: 6) { Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(EchoTheme.gradient); Text("Echo AI").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) } }
                Text(message.text).font(.system(size: 15)).foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(message.role == .user ? AnyShapeStyle(EchoTheme.gradient) : AnyShapeStyle(EchoTheme.cardBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                if let cards = message.cards { ForEach(cards) { card in ChatCardView(card: card) } }
            }
            if message.role == .assistant { Spacer(minLength: 50) }
        }
    }
}

struct ChatCardView: View {
    let card: ChatMessage.ChatCard
    var body: some View {
        HStack(spacing: 10) {
            if let c = card.contact { Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 36, height: 36).overlay(Text(c.givenName.prefix(1)).font(.system(size: 16, weight: .bold)).foregroundStyle(EchoTheme.accentColor)) }
            VStack(alignment: .leading, spacing: 2) { Text(card.title).font(.system(size: 14, weight: .semibold)); Text(card.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) }
            Spacer()
            if let score = card.score { ScoreRing(score: score, size: 40) }
        }.padding(12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(EchoTheme.accentColor.opacity(0.2), lineWidth: 1))
    }
}

struct ThinkingBubble: View {
    @State private var dotOffset: CGFloat = 0
    var body: some View {
        HStack {
            HStack(spacing: 5) { ForEach(0..<3) { i in Circle().fill(EchoTheme.accentColor.opacity(0.6)).frame(width: 8, height: 8).offset(y: dotOffset).animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: dotOffset) } }
                .padding(.horizontal, 16).padding(.vertical, 12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 18))
            Spacer()
        }.onAppear { dotOffset = -6 }
    }
}

struct AIChatEngine {
    static func respond(to query: String, contacts: [EchoContact]) -> (text: String, cards: [ChatMessage.ChatCard]) {
        let q = query.lowercased()
        if q.contains("今天") && (q.contains("联系") || q.contains("谁")) { return todayRecommendation(contacts) }
        if q.contains("失去") { return losingTouch(contacts) }
        if q.contains("周") || q.contains("总结") { return weeklySummary(contacts) }
        if q.contains("写") || q.contains("消息") || q.contains("开场") || q.contains("说什么") { return openingLineHelp(contacts) }
        if q.contains("健康") || q.contains("最低") || q.contains("分") { return lowestHealth(contacts) }
        if let c = contacts.first(where: { q.contains($0.givenName.lowercased()) || ($0.familyName.count > 0 && q.contains($0.fullName.lowercased())) }) { return contactAnalysis(c) }
        if q.contains("多少") || q.contains("统计") { return statsOverview(contacts) }
        if q.contains("提醒") || q.contains("通知") { return reminderHelp(contacts) }
        if q.contains("建议") || q.contains("目标") { return goalsHelp(contacts) }
        return ("我可以帮你：\n- 今天该联系谁？\n- 我和谁正在失去联系？\n- 本周关系总结\n- 帮我写条消息\n- 某某的关系怎么样？", [])
    }
    static func todayRecommendation(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let r = AIEngine.generateSmartNotifications(for: c).prefix(5)
        if r.isEmpty { return ("太棒了！所有关系都在健康范围内", []) }
        let cards = r.map { ChatMessage.ChatCard(type: .contactCard, contact: $0.contact, title: $0.contact.givenName, detail: $0.reason, score: AIEngine.healthScore(for: $0.contact).score) }
        return ("今天建议联系这 " + String(r.count) + " 个人", cards)
    }
    static func losingTouch(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let r = c.filter { let l = AIEngine.healthScore(for: $0).level; return l == .fading || l == .critical }
        if r.isEmpty { return ("没有正在失去联系的关系", []) }
        let cards = r.prefix(5).map { ChatMessage.ChatCard(type: .healthCard, contact: $0, title: $0.givenName, detail: String(AIEngine.healthScore(for: $0).score) + "/100", score: AIEngine.healthScore(for: $0).score) }
        return (String(r.count) + " 段关系正在淡化，建议尽快联系", cards)
    }
    static func weeklySummary(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let s = AIEngine.generateWeeklySummary(contacts: c)
        let text = "本周（" + s.weekRange + "）\n- 联系 " + String(s.totalReachouts) + " 次\n- 新增 " + String(s.newConnections) + " 人\n- 加深 " + String(s.relationshipsStrengthened) + " 人\n- 需关注 " + String(s.relationshipsAtRisk) + " 人"
        return (text, s.topInsights.prefix(3).map { ChatMessage.ChatCard(type: .summaryCard, contact: nil, title: $0.title, detail: $0.detail, score: nil) })
    }
    static func openingLineHelp(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        guard let f = c.sorted(by: { ($0.lastReachedOut ?? .distantPast) < ($1.lastReachedOut ?? .distantPast) }).first else { return ("请先导入联系人", []) }
        let lines = AIEngine.generateOpeningLines(for: f, channel: .messaged)
        return ("为 " + f.givenName + " 生成的开场白：\n\n" + lines.enumerated().map { i, l in String(i+1) + ". " + l.text + "\n" + l.context }.joined(separator: "\n\n"), [ChatMessage.ChatCard(type: .suggestionCard, contact: f, title: f.givenName, detail: EchoEngine.gapDescription(for: f), score: AIEngine.healthScore(for: f).score)])
    }
    static func lowestHealth(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let s = c.map { ($0, AIEngine.healthScore(for: $0)) }.sorted { $0.1.score < $1.1.score }.prefix(5)
        return ("健康分最低：\n" + s.enumerated().map { i, p in String(i+1) + ". " + p.0.givenName + " — " + String(p.1.score) + "分" }.joined(separator: "\n"), s.map { ChatMessage.ChatCard(type: .healthCard, contact: $0.0, title: $0.0.givenName, detail: String($0.1.score) + "/100 — " + $0.1.level.label, score: $0.1.score) })
    }
    static func contactAnalysis(_ c: EchoContact) -> (String, [ChatMessage.ChatCard]) {
        let h = AIEngine.healthScore(for: c)
        var text = c.givenName + "\n健康分：" + String(h.score) + "/100（" + h.level.label + "）\n\n"
        for f in h.factors { text += "- " + f.name + ":" + String(Int(f.score * 100)) + "%\n" }
        text += "\n" + h.recommendation
        return (text, AIEngine.generateInsights(for: c).prefix(3).map { ChatMessage.ChatCard(type: .suggestionCard, contact: c, title: $0.title, detail: $0.detail, score: nil) })
    }
    static func statsOverview(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let avg = c.isEmpty ? 0 : c.map { AIEngine.healthScore(for: $0).score }.reduce(0, +) / c.count
        return ("关系网络\n- 联系人：" + String(c.count) + "\n- 互动：" + String(c.flatMap { $0.interactions }.count) + " 次\n- 平均健康分：" + String(avg) + "/100", [])
    }
    static func reminderHelp(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let r = AIEngine.generateSmartNotifications(for: c).prefix(5)
        if r.isEmpty { return ("没有待处理提醒", []) }
        return (String(r.count) + " 条智能提醒", r.map { ChatMessage.ChatCard(type: .contactCard, contact: $0.contact, title: $0.contact.givenName, detail: $0.reason, score: AIEngine.healthScore(for: $0.contact).score) })
    }
    static func goalsHelp(_ c: [EchoContact]) -> (String, [ChatMessage.ChatCard]) {
        let g = AIEngine.suggestRelationshipGoals(contacts: c)
        if g.isEmpty { return ("没有需要改善的目标", []) }
        return (String(g.count) + " 个关系目标：\n" + g.map { "- " + $0.contact.givenName + ":" + $0.goal }.joined(separator: "\n"), g.prefix(5).map { ChatMessage.ChatCard(type: .suggestionCard, contact: $0.contact, title: $0.goal, detail: $0.detail, score: AIEngine.healthScore(for: $0.contact).score) })
    }
}