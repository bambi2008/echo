import SwiftUI
import SwiftData

/// AI 关系智能面板 — 展示在联系人详情页底部
struct AIPanelView: View {
    let contact: EchoContact
    @Environment(\.modelContext) private var modelContext
    @State private var health: RelationshipHealth?
    @State private var insights: [AIInsight] = []
    @State private var openingLines: [AIOpeningLine] = []
    @State private var showOpeningLines = false
    @State private var selectedChannel: InteractionType = .messaged
    @State private var isAnalyzing = true

    var body: some View {
        VStack(spacing: 16) {
            if let health = health { HealthScoreCard(health: health).transition(.scale.combined(with: .opacity)) }
            if isAnalyzing {
                HStack(spacing: 12) { ProgressView().tint(EchoTheme.accentColor); Text("AI 正在分析关系数据...").font(EchoTheme.captionFont).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("AI 洞察", icon: "brain.head.profile")
                    ForEach(insights) { insight in InsightCard(insight: insight) }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("AI 开场白建议", icon: "text.bubble")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(InteractionType.allCases.filter { $0 != .reachedOut }, id: \.self) { type in ChannelChip(type: type, isSelected: selectedChannel == type, action: { selectedChannel = type; refreshOpeningLines() }) } }
                }
                if showOpeningLines && !openingLines.isEmpty { ForEach(openingLines) { line in OpeningLineCard(line: line) }.transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity)) }
            }
        }
        .padding(.vertical, 8)
        .task { await runAnalysis() }
        .onChange(of: contact.lastReachedOut) { _, _ in Task { await runAnalysis() } }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) { Image(systemName: icon).font(.system(size: 13)).foregroundStyle(EchoTheme.accentColor); Text(title).font(EchoTheme.sectionFont).foregroundStyle(.primary); Spacer() }
    }

    private func runAnalysis() async {
        isAnalyzing = true
        let h = AIEngine.healthScore(for: contact); let i = AIEngine.generateInsights(for: contact); let lines = AIEngine.generateOpeningLines(for: contact, channel: selectedChannel)
        await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { self.health = h; self.insights = i; self.openingLines = lines; self.showOpeningLines = !lines.isEmpty; self.isAnalyzing = false } }
    }

    private func refreshOpeningLines() { let lines = AIEngine.generateOpeningLines(for: contact, channel: selectedChannel); withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.openingLines = lines } }
}

private struct HealthScoreCard: View {
    let health: RelationshipHealth
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) { Image(systemName: health.level.icon).font(.system(size: 16)).foregroundStyle(healthColor); Text("关系健康").font(EchoTheme.sectionFont).foregroundStyle(.primary) }
                    Text(health.level.label).font(.system(size: 28, weight: .bold)).foregroundStyle(healthColor)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle().trim(from: 0, to: CGFloat(health.score) / 100).stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.easeOut(duration: 0.8), value: health.score)
                    Text("\(health.score)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(healthColor)
                }.frame(width: 64, height: 64)
            }
            VStack(spacing: 6) {
                ForEach(health.factors.indices, id: \.self) { idx in
                    let factor = health.factors[idx]
                    HStack { Text(factor.name).font(EchoTheme.captionFont).foregroundStyle(.secondary); Spacer(); Text(factor.detail).font(EchoTheme.captionFont).foregroundStyle(.secondary); ProgressView(value: factor.score).tint(factor.score > 0.6 ? .green : factor.score > 0.3 ? .orange : .red).frame(width: 60) }
                }
            }
            HStack(alignment: .top, spacing: 8) { Image(systemName: "lightbulb.fill").font(.system(size: 12)).foregroundStyle(.yellow); Text(health.recommendation).font(EchoTheme.captionFont).foregroundStyle(.primary); Spacer() }.padding(10).background(Color.yellow.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
        }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
    private var healthColor: Color { Color(hex: health.level.color) }
}

private struct InsightCard: View {
    let insight: AIInsight
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon).font(.system(size: 16)).foregroundStyle(severityColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) { Text(insight.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary); Text(insight.detail).font(EchoTheme.captionFont).foregroundStyle(.secondary) }
            Spacer()
        }.padding(12).background(severityColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private var severityColor: Color { switch insight.severity { case .critical: return Color(hex: "#FF453A"); case .warning: return Color(hex: "#FF9F0A"); case .positive: return Color(hex: "#30D158"); case .info: return Color(hex: "#0A84FF") } }
}

private struct OpeningLineCard: View {
    let line: AIOpeningLine
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(line.text).font(.system(size: 15)).foregroundStyle(.primary).lineSpacing(4)
            HStack(spacing: 4) { Image(systemName: "info.circle").font(.system(size: 11)); Text(line.context).font(.system(size: 11)) }.foregroundStyle(.secondary)
        }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10)).contextMenu { Button { UIPasteboard.general.string = line.text } label: { Label("复制", systemImage: "doc.on.doc") } }
    }
}

private struct ChannelChip: View {
    let type: InteractionType; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) { Image(systemName: type.icon).font(.system(size: 12)); Text(type.label).font(.system(size: 13, weight: isSelected ? .semibold : .regular)) }
            .padding(.horizontal, 12).padding(.vertical, 8).background(isSelected ? EchoTheme.accentColor : Color.gray.opacity(0.15)).foregroundStyle(isSelected ? .white : .primary).clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}
