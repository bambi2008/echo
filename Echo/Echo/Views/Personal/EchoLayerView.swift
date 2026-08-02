import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\EchoContact.lastReachedOut, order: .reverse)]) private var contacts: [EchoContact]
    @State private var searchText = ""
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) { Text("Echo Layer").tag(0); Text("AI 洞察").tag(1) }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8)
                if selectedTab == 0 { echoLayerTab } else { aiInsightsTab }
            }
            .background(EchoTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Echo")
            .searchable(text: $searchText, prompt: "搜索联系人、笔记...")
        }
    }

    private var echoLayerTab: some View {
        ScrollView {
            if filteredContacts.isEmpty { VStack(spacing: 16) { Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundStyle(.secondary); Text(searchText.isEmpty ? "还没有联系人在 Echo Layer" : "没有找到匹配的联系人").font(EchoTheme.sectionFont).foregroundStyle(.secondary) }.padding(.top, 80) }
            else {
                let urgentCount = filteredContacts.filter { AIEngine.smartReminder(for: $0)?.priority == .urgent }.count
                if urgentCount > 0 { HStack(spacing: 10) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red); Text("\(urgentCount) 位联系人超过30天未联系 — 关系正在淡化").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary); Spacer() }.padding(12).background(Color.red.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16).padding(.top, 8) }
                LazyVStack(spacing: 12) { ForEach(EchoEngine.sortedEchoLayer(from: filteredContacts)) { contact in NavigationLink { ContactDetailView(contact: contact) } label: { AIContactCard(contact: contact) }.buttonStyle(.plain) } }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            }
        }
    }

    private var aiInsightsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                WeeklySummaryCard()
                SmartRemindersSection(contacts: contacts)
                HealthDistributionCard(contacts: contacts)
                BatchSuggestionsSection(contacts: contacts)
                GoalsSection(contacts: contacts)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
        }
    }

    private var filteredContacts: [EchoContact] { if searchText.isEmpty { return contacts }; return AIEngine.smartSearch(query: searchText, in: contacts).map { $0.0 } }
}

struct AIContactCard: View {
    let contact: EchoContact
    @State private var healthScore: Int = 0
    @State private var healthLevel: RelationshipHealth.HealthLevel = .stable
    var body: some View {
        HStack(spacing: 14) {
            if let data = contact.thumbnailData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(Circle()) }
            else { ZStack { Circle().fill(healthColor.opacity(0.15)).frame(width: 52, height: 52); Text(contact.givenName.prefix(1).uppercased()).font(.system(size: 20, weight: .bold)).foregroundStyle(healthColor) } }
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) { Image(systemName: healthLevel.icon).font(.system(size: 11)).foregroundStyle(healthColor); Text(EchoEngine.gapDescription(for: contact)).font(EchoTheme.captionFont).foregroundStyle(.secondary) }
            }
            Spacer()
            VStack(spacing: 2) {
                ZStack { Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4).frame(width: 36, height: 36); Circle().trim(from: 0, to: CGFloat(healthScore) / 100).stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 36, height: 36).rotationEffect(.degrees(-90)); Text("\(healthScore)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(healthColor) }
                Text(healthLevel.label).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }.padding(14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius)).onAppear { let health = AIEngine.healthScore(for: contact); healthScore = health.score; healthLevel = health.level }
    }
    private var healthColor: Color { Color(hex: healthLevel.color) }
}

private struct WeeklySummaryCard: View {
    @State private var summary: AIWeeklySummary?
    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: "sparkles").foregroundStyle(EchoTheme.accentColor); Text("AI 关系周报").font(EchoTheme.sectionFont); Spacer(); Text(s.weekRange).font(.system(size: 12)).foregroundStyle(.secondary) }
                HStack(spacing: 12) { SummaryStat(value: "\(s.totalReachouts)", label: "次联系", icon: "hand.wave", color: .blue); SummaryStat(value: "\(s.relationshipsStrengthened)", label: "关系加深", icon: "heart.fill", color: .green); SummaryStat(value: "\(s.relationshipsAtRisk)", label: "需要关注", icon: "exclamationmark.triangle", color: .orange) }
                if !s.recommendedActions.isEmpty { VStack(alignment: .leading, spacing: 6) { Text("建议行动").font(.system(size: 13, weight: .semibold)); ForEach(s.recommendedActions.indices, id: \.self) { idx in HStack(alignment: .top, spacing: 6) { Text("•").foregroundStyle(EchoTheme.accentColor); Text(s.recommendedActions[idx]).font(EchoTheme.captionFont) } } } }
                if !s.topInsights.isEmpty { Divider(); VStack(alignment: .leading, spacing: 6) { Text("AI 洞察").font(.system(size: 13, weight: .semibold)); ForEach(s.topInsights.prefix(3)) { insight in HStack(alignment: .top, spacing: 6) { Image(systemName: insight.icon).font(.system(size: 12)).foregroundStyle(EchoTheme.accentColor); Text("\(insight.title): \(insight.detail)").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) } } } }
            }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
        } else { ProgressView("AI 正在生成周报...").frame(maxWidth: .infinity).padding(20) }
    }
}

private struct SmartRemindersSection: View {
    let contacts: [EchoContact]
    var body: some View {
        let reminders = AIEngine.generateSmartNotifications(for: contacts).prefix(5)
        if !reminders.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "bell.badge").foregroundStyle(EchoTheme.accentColor); Text("AI 智能提醒").font(EchoTheme.sectionFont) }
                ForEach(Array(reminders), id: \.contact.systemIdentifier) { reminder in
                    NavigationLink { ContactDetailView(contact: reminder.contact) } label: {
                        HStack(spacing: 12) { Circle().fill(priorityColor(reminder.priority)).frame(width: 10, height: 10); VStack(alignment: .leading, spacing: 2) { Text(reminder.contact.fullName).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary); Text(reminder.reason).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer(); Image(systemName: reminder.suggestedChannel.icon).font(.system(size: 14)).foregroundStyle(.secondary) }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func priorityColor(_ p: SmartReminder.ReminderPriority) -> Color { switch p { case .urgent: return .red; case .important: return .orange; case .nice: return .blue } }
}

private struct HealthDistributionCard: View {
    let contacts: [EchoContact]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "chart.bar.fill").foregroundStyle(EchoTheme.accentColor); Text("关系健康分布").font(EchoTheme.sectionFont) }
            let scores = contacts.map { AIEngine.healthScore(for: $0) }
            let counts: [(RelationshipHealth.HealthLevel, Int)] = [(.thriving, scores.filter { $0.level == .thriving }.count), (.stable, scores.filter { $0.level == .stable }.count), (.atRisk, scores.filter { $0.level == .atRisk }.count), (.fading, scores.filter { $0.level == .fading }.count), (.critical, scores.filter { $0.level == .critical }.count)].filter { $0.1 > 0 }
            ForEach(counts, id: \.0) { level, count in
                HStack { Image(systemName: level.icon).font(.system(size: 12)).foregroundStyle(Color(hex: level.color)).frame(width: 20); Text(level.label).font(.system(size: 13)).foregroundStyle(.secondary); Spacer(); GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)); RoundedRectangle(cornerRadius: 4).fill(Color(hex: level.color)).frame(width: contacts.count > 0 ? geo.size.width * (Double(count) / Double(contacts.count)) : 0) } }.frame(width: 100, height: 8); Text("\(count)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary).frame(width: 28, alignment: .trailing) }
            }
        }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
}

private struct BatchSuggestionsSection: View {
    let contacts: [EchoContact]
    var body: some View {
        let groups = AIEngine.batchSuggestions(contacts: contacts)
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "person.3.fill").foregroundStyle(EchoTheme.accentColor); Text("AI 批量联系建议").font(EchoTheme.sectionFont) }
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: group.icon).font(.system(size: 14)).foregroundStyle(EchoTheme.accentColor); Text(group.title).font(.system(size: 15, weight: .semibold)) }
                        Text(group.subtitle).font(EchoTheme.captionFont).foregroundStyle(.secondary)
                        ForEach(group.contacts.prefix(5)) { contact in NavigationLink { ContactDetailView(contact: contact) } label: { HStack(spacing: 8) { Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 28, height: 28).overlay { Text(contact.givenName.prefix(1)).font(.system(size: 12, weight: .bold)).foregroundStyle(EchoTheme.accentColor) }; Text(contact.fullName).font(.system(size: 14)).foregroundStyle(.primary); Spacer(); Text(EchoEngine.gapDescription(for: contact)).font(.system(size: 11)).foregroundStyle(.secondary) } }.buttonStyle(.plain) }
                    }.padding(14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct GoalsSection: View {
    let contacts: [EchoContact]
    var body: some View {
        let goals = AIEngine.suggestRelationshipGoals(contacts: contacts).prefix(5)
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "target").foregroundStyle(EchoTheme.accentColor); Text("AI 关系目标").font(EchoTheme.sectionFont) }
                ForEach(goals) { goal in NavigationLink { ContactDetailView(contact: goal.contact) } label: { HStack(spacing: 12) { Image(systemName: goal.priority == .high ? "flag.fill" : "flag").foregroundStyle(goal.priority == .high ? .red : .orange); VStack(alignment: .leading, spacing: 2) { Text("\(goal.contact.fullName): \(goal.goal)").font(.system(size: 14, weight: .medium)).foregroundStyle(.primary); Text(goal.detail).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer() }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain) }
            }
        }
    }
}

private struct SummaryStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View { VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color); Text(value).font(.system(size: 20, weight: .bold, design: .rounded)); Text(label).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 10).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10)) }
}
