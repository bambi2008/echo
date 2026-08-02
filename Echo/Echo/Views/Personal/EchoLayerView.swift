import SwiftUI
import SwiftData
struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\EchoContact.lastReachedOut, order: .reverse)]) private var contacts: [EchoContact]
    @State private var searchText = ""; @State private var selectedTab = 0; @State private var ahaContact: EchoContact?; @State private var showAIChat = false; @State private var pullDistance: CGFloat = 0; @State private var aiSuggestion: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) { Text("Echo Layer").tag(0); Text("AI 洞察").tag(1) }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8)
                if selectedTab == 0 { echoLayerTab } else { aiInsightsTab }
            }.background(EchoTheme.backgroundGradient.ignoresSafeArea()).navigationTitle("Echo").searchable(text: $searchText, prompt: "搜索联系人...")
        }
    }
    private var echoLayerTab: some View {
        ScrollView {
            PullReachHint(pullDistance: pullDistance, suggestion: aiSuggestion).padding(.top, 8)
            if !filteredContacts.isEmpty { SmartContextCards(contacts: filteredContacts, onReach: { c in ahaContact = c }, onCompose: { c in ahaContact = c }).padding(.horizontal, 16).padding(.top, 8) }
            if filteredContacts.isEmpty { emptyState } else {
                let urgentCount = filteredContacts.filter { AIEngine.smartReminder(for: $0)?.priority == .urgent }.count
                if urgentCount > 0 { HStack(spacing: 10) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red); Text("\(urgentCount) 位联系人超过30天未联系").font(.system(size: 13, weight: .medium)); Spacer() }.padding(12).background(Color.red.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16).padding(.top, 8) }
                LazyVStack(spacing: 12) { ForEach(EchoEngine.sortedEchoLayer(from: filteredContacts)) { contact in NavigationLink { ContactDetailView(contact: contact) } label: { AIContactCard(contact: contact) }.buttonStyle(.plain) } }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 100)
            }
        }
    }
    private var aiInsightsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                RelationshipWeatherView(contacts: contacts)
                StreakCalendarView(interactions: contacts.flatMap { $0.interactions })
                WeeklySummaryCard()
                SmartRemindersSection(contacts: contacts)
                HealthDistributionCard(contacts: contacts)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 100)
        }
    }
    private var emptyState: some View {
        VStack(spacing: 16) { Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundStyle(.secondary); Text(searchText.isEmpty ? "还没有联系人在 Echo Layer" : "没有找到匹配的联系人").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary) }.padding(.top, 80)
    }
    private var filteredContacts: [EchoContact] { if searchText.isEmpty { return contacts }; return contacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) } }
}
struct AIContactCard: View {
    let contact: EchoContact; @State private var healthScore: Int = 0; @State private var healthLevel: RelationshipHealth.HealthLevel = .stable
    var body: some View {
        HStack(spacing: 14) {
            if let d = contact.thumbnailData, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(Circle()) } else { ZStack { Circle().fill(healthColor.opacity(0.15)).frame(width: 52, height: 52); Text(contact.givenName.prefix(1).uppercased()).font(.system(size: 20, weight: .bold)).foregroundStyle(healthColor) } }
            VStack(alignment: .leading, spacing: 4) { Text(contact.fullName).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary); HStack(spacing: 6) { Image(systemName: healthLevel.icon).font(.system(size: 11)).foregroundStyle(healthColor); Text(EchoEngine.gapDescription(for: contact)).font(.system(size: 12)).foregroundStyle(.secondary) } }; Spacer(); VStack(spacing: 2) { ZStack { Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4).frame(width: 36, height: 36); Circle().trim(from: 0, to: CGFloat(healthScore) / 100).stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 36, height: 36).rotationEffect(.degrees(-90)); Text("\(healthScore)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(healthColor) }; Text(healthLevel.label).font(.system(size: 9)).foregroundStyle(.secondary) }
        }.padding(14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)).onAppear { let h = AIEngine.healthScore(for: contact); healthScore = h.score; healthLevel = h.level }
    }
    private var healthColor: Color { Color(hex: healthLevel.color) }
}
private struct WeeklySummaryCard: View { @State private var summary: AIWeeklySummary?; var body: some View { if let s = summary { VStack(alignment: .leading, spacing: 12) { HStack { Image(systemName: "sparkles").foregroundStyle(EchoTheme.accentColor); Text("AI 关系周报").font(.system(size: 16, weight: .bold)); Spacer(); Text(s.weekRange).font(.system(size: 12)).foregroundStyle(.secondary) }; HStack(spacing: 12) { statVal("\(s.totalReachouts)", "次联系", "hand.wave", .blue); statVal("\(s.relationshipsStrengthened)", "关系加深", "heart.fill", .green); statVal("\(s.relationshipsAtRisk)", "需要关注", "exclamationmark.triangle", .orange) }; if !s.recommendedActions.isEmpty { VStack(alignment: .leading, spacing: 6) { Text("建议行动").font(.system(size: 13, weight: .semibold)); ForEach(s.recommendedActions.indices, id: \.self) { i in HStack(spacing: 6) { Text("•").foregroundStyle(EchoTheme.accentColor); Text(s.recommendedActions[i]).font(.system(size: 12)) } } } } }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)) } else { ProgressView("AI 正在生成周报...").padding(20) } }
    private func statVal(_ v: String, _ l: String, _ i: String, _ c: Color) -> some View { VStack(spacing: 4) { Image(systemName: i).font(.system(size: 16)).foregroundStyle(c); Text(v).font(.system(size: 20, weight: .bold, design: .rounded)); Text(l).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } }
private struct SmartRemindersSection: View { let contacts: [EchoContact]; var body: some View { VStack(alignment: .leading, spacing: 10) { Text("智能提醒").font(.system(size: 16, weight: .bold)); ForEach(0..<contacts.count) { i in let c = contacts[i]; if let r = AIEngine.smartReminder(for: c) { HStack(spacing: 10) { Image(systemName: r.suggestedChannel.icon).font(.system(size: 14)).foregroundStyle(r.priority == .urgent ? .red : .orange).frame(width: 32, height: 32).background((r.priority == .urgent ? Color.red : Color.orange).opacity(0.15)).clipShape(Circle()); VStack(alignment: .leading, spacing: 2) { Text(c.givenName).font(.system(size: 14, weight: .semibold)); Text(r.reason).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer(); Text(r.suggestedTime.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary) }.padding(10).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10)) } } }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)) } }
private struct HealthDistributionCard: View { let contacts: [EchoContact]; var body: some View { VStack(alignment: .leading, spacing: 10) { Text("关系健康分布").font(.system(size: 16, weight: .bold)); let counts: [RelationshipHealth.HealthLevel: Int] = Dictionary(grouping: contacts.map { AIEngine.healthScore(for: $0).level }, by: { $0 }).mapValues { $0.count }; HStack(spacing: 4) { ForEach([RelationshipHealth.HealthLevel.thriving, .stable, .atRisk, .fading, .critical], id: \.rawValue) { level in let count = counts[level] ?? 0; let total = max(contacts.count, 1); let pct = CGFloat(count) / CGFloat(total); RoundedRectangle(cornerRadius: 3).fill(Color(hex: level.color)).frame(maxWidth: .infinity).frame(height: 60).overlay(Text("\(count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)).scaleEffect(y: max(pct, 0.05), anchor: .bottom) } }.frame(height: 60); HStack(spacing: 4) { ForEach([RelationshipHealth.HealthLevel.thriving, .stable, .atRisk, .fading, .critical], id: \.rawValue) { level in Text(level.label).font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity) } } }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)) } }
private struct GoalsSection: View { let contacts: [EchoContact]; var body: some View { VStack(alignment: .leading, spacing: 10) { Text("关系目标").font(.system(size: 16, weight: .bold)); Text("每周联系至少 5 位 Echo Layer 中的人").font(.system(size: 13)).foregroundStyle(.secondary); let reached = min(contacts.filter { if let l = $0.lastReachedOut { Calendar.current.dateComponents([.day], from: l, to: Date()).day ?? 0 < 7 } else { false } }.count, 5); ProgressView(value: Double(reached), total: 5).tint(EchoTheme.accentColor); Text("本周已联系 \(reached)/5").font(.system(size: 11)).foregroundStyle(.secondary) }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)) } }