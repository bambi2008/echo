import SwiftUI
import SwiftData

struct AIContactCard: View {
    let contact: EchoContact
    @State private var healthScore: Int = 0
    @State private var healthLevel: RelationshipHealth.HealthLevel = .stable
    var body: some View {
        HStack(spacing: 14) {
            if let data = contact.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(healthColor.opacity(0.15)).frame(width: 52, height: 52)
                    Text(contact.givenName.prefix(1).uppercased()).font(.system(size: 20, weight: .bold)).foregroundStyle(healthColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Image(systemName: healthLevel.icon).font(.system(size: 11)).foregroundStyle(healthColor)
                    Text(EchoEngine.gapDescription(for: contact)).font(EchoTheme.captionFont).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4).frame(width: 36, height: 36)
                    Circle().trim(from: 0, to: CGFloat(healthScore) / 100).stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                    Text("\(healthScore)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(healthColor)
                }
                Text(healthLevel.label).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
        .onAppear { let h = AIEngine.healthScore(for: contact); healthScore = h.score; healthLevel = h.level }
    }
    private var healthColor: Color { Color(hex: healthLevel.color) }
}

struct UrgentBanner: View {
    let count: Int
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text("\(count) 位联系人超过30天未联系 — 关系正在淡化").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            Spacer()
        }
        .padding(12).background(Color.red.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct WeeklySummaryCard: View {
    @State private var summary: AIWeeklySummary?
    var body: some View {
        if let summary = summary {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(EchoTheme.accentColor)
                    Text("AI 关系周报").font(EchoTheme.sectionFont)
                    Spacer()
                    Text(summary.weekRange).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    SummaryStat(value: "\(summary.totalReachouts)", label: "次联系", icon: "hand.wave", color: .blue)
                    SummaryStat(value: "\(summary.relationshipsStrengthened)", label: "关系加深", icon: "heart.fill", color: .green)
                    SummaryStat(value: "\(summary.relationshipsAtRisk)", label: "需要关注", icon: "exclamationmark.triangle", color: .orange)
                }
                if !summary.recommendedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("建议行动").font(.system(size: 13, weight: .semibold))
                        ForEach(0..<summary.recommendedActions.count) { idx in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(EchoTheme.accentColor)
                                Text(summary.recommendedActions[idx]).font(EchoTheme.captionFont)
                            }
                        }
                    }
                }
                HStack { Spacer(); Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            .padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
        } else {
            ProgressView("AI 正在生成周报...").padding(20)
                .onAppear { summary = AIEngine.generateWeeklySummary(contacts: []) }
        }
    }
}

struct SmartRemindersSection: View {
    let contacts: [EchoContact]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "bell.badge").foregroundStyle(.orange); Text("智能提醒").font(EchoTheme.sectionFont) }
            let reminders = contacts.compactMap { AIEngine.smartReminder(for: $0) }.sorted { $0.priority.rawValue > $1.priority.rawValue }
            ForEach(Array(reminders.enumerated()), id: \.offset) { idx, r in
                HStack(spacing: 10) {
                    Circle().fill(r.priority == .urgent ? Color.red : r.priority == .important ? Color.orange : Color.gray).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.contact.givenName).font(.system(size: 14, weight: .medium))
                        Text(r.reason).font(EchoTheme.captionFont).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(r.suggestedTime.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(10).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if reminders.isEmpty { Text("暂无提醒").font(EchoTheme.captionFont).foregroundStyle(.secondary).padding(.vertical, 8) }
        }
    }
}

struct HealthDistributionCard: View {
    let contacts: [EchoContact]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "heart.text.clipboard").foregroundStyle(.pink); Text("健康分布").font(EchoTheme.sectionFont) }
            Text("健康数据加载中...").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
}

struct BatchSuggestionsSection: View {
    let contacts: [EchoContact]
    var body: some View {
        NavigationLink { BatchReachView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill").font(.system(size: 18)).foregroundStyle(.purple).frame(width: 36, height: 36).background(Color.purple.opacity(0.15)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("批量联系").font(.system(size: 15, weight: .semibold))
                    Text("AI 为每位联系人生成个性化开场白").font(EchoTheme.captionFont).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

struct GoalsSection: View {
    let contacts: [EchoContact]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "target").foregroundStyle(.green); Text("关系目标").font(EchoTheme.sectionFont) }
            let goals = []
                        if goals.isEmpty { Text("暂无目标建议").font(EchoTheme.captionFont).foregroundStyle(.secondary).padding(.vertical, 8) }
        }
    }
}

struct SummaryStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct Bar: View {
    let value: CGFloat; let maxValue: CGFloat; let color: Color
    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * min(1, value / maxValue), height: 6)
        }.frame(height: 6)
    }
}