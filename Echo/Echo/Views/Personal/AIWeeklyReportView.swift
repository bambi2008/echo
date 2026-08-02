import SwiftUI
import SwiftData

struct AIWeeklyReportView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }) var contacts: [EchoContact]
    private var summary: AIWeeklySummary { AIEngine.generateWeeklySummary(contacts: contacts) }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                reportHeader; statsGrid; healthDistribution
                if !summary.topInsights.isEmpty { insightsSection }
                if !summary.recommendedActions.isEmpty { actionsSection }
                footer
            }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 32)
        }.background(EchoTheme.darkBackground).navigationTitle("AI 周报").navigationBarTitleDisplayMode(.inline)
    }
    private var reportHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal.fill").font(.system(size: 36)).foregroundStyle(EchoTheme.gradient)
            Text(summary.weekRange).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            Text("关系健康周报").font(EchoTheme.titleFont)
        }.frame(maxWidth: .infinity).padding(.vertical, 20).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "主动联系", value: String(summary.totalReachouts), icon: "hand.wave.fill", color: .blue)
            StatCard(title: "新增联系人", value: String(summary.newConnections), icon: "person.badge.plus", color: .green)
            StatCard(title: "关系加深", value: String(summary.relationshipsStrengthened), icon: "heart.fill", color: .pink)
            StatCard(title: "需要关注", value: String(summary.relationshipsAtRisk), icon: "exclamationmark.triangle.fill", color: .orange)
        }
    }
    private var healthDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) { Image(systemName: "chart.pie.fill").font(.system(size: 14)).foregroundStyle(EchoTheme.gradient); Text("关系健康分布").font(.system(size: 16, weight: .bold)); Spacer() }
            VStack(spacing: 8) {
                let levels = RelationshipHealth.HealthLevel.allCases.sorted { rank($0) > rank($1) }
                ForEach(0..<levels.count) { i in
                    let level = levels[i]
                    let count = summary.healthDistribution[level] ?? 0
                    let pct = Double(count) / Double(max(contacts.count, 1))
                    HStack(spacing: 12) {
                        Image(systemName: level.icon).font(.system(size: 14)).foregroundStyle(Color(hex: level.color)).frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(level.label).font(.system(size: 14, weight: .medium)); Spacer(); Text(String(count) + " 人").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.secondary) }
                            GeometryReader { geo in RoundedRectangle(cornerRadius: 4).fill(Color(hex: level.color).opacity(0.3)).overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color(hex: level.color)).frame(width: geo.size.width * pct) } }.frame(height: 8)
                        }
                    }
                }
            }.padding(16).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) { Image(systemName: "brain.head.profile").font(.system(size: 14)).foregroundStyle(EchoTheme.gradient); Text("AI 关键洞察").font(.system(size: 16, weight: .bold)); Spacer() }
            VStack(spacing: 10) {
                ForEach(summary.topInsights) { insight in
                    HStack(spacing: 10) {
                        Image(systemName: insight.icon).font(.system(size: 14)).foregroundStyle(severityColor(insight.severity)).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) { Text(insight.title).font(.system(size: 14, weight: .semibold)); Text(insight.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3) }
                        Spacer()
                    }.padding(12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) { Image(systemName: "lightbulb.fill").font(.system(size: 14)).foregroundStyle(EchoTheme.gradient); Text("推荐行动").font(.system(size: 16, weight: .bold)); Spacer() }
            VStack(spacing: 8) {
                ForEach(0..<summary.recommendedActions.count) { i in
                    HStack(spacing: 10) { Image(systemName: "arrow.right.circle.fill").font(.system(size: 14)).foregroundStyle(EchoTheme.gradient); Text(summary.recommendedActions[i]).font(.system(size: 14)); Spacer() }.padding(12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    private var footer: some View {
        VStack(spacing: 4) { Text("由 Echo AI 在设备端生成").font(.system(size: 11)).foregroundStyle(.secondary); Text("🔒 你的数据从未离开这台设备").font(.system(size: 11, weight: .medium)).foregroundStyle(.green) }
    }
    private func severityColor(_ s: AIInsight.InsightSeverity) -> Color { switch s { case .critical: return .red; case .warning: return .orange; case .positive: return .green; case .info: return .blue } }
    private func rank(_ l: RelationshipHealth.HealthLevel) -> Int { switch l { case .thriving: return 5; case .stable: return 4; case .atRisk: return 3; case .fading: return 2; case .critical: return 1 } }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color); Text(value).font(.system(size: 28, weight: .bold, design: .rounded)); Text(title).font(.system(size: 11)).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity).padding(.vertical, 16).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension RelationshipHealth.HealthLevel: CaseIterable { static var allCases: [RelationshipHealth.HealthLevel] { [.thriving, .stable, .atRisk, .fading, .critical] } }