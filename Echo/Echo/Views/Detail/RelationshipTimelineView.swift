import SwiftUI
import SwiftData
import NaturalLanguage

struct RelationshipTimelineView: View {
    let contact: EchoContact
    private var interactions: [Interaction] { contact.interactions.sorted { $0.date < $1.date } }
    private var notes: [Note] { contact.notes.sorted { $0.createdAt < $1.createdAt } }
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        for i in interactions { items.append(TimelineItem(date: i.date, type: .interaction(i))) }
        for n in notes { items.append(TimelineItem(date: n.createdAt, type: .note(n))) }
        return items.sorted { $0.date > $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sentimentChart.padding(.bottom, 20)
                statsRow.padding(.bottom, 24)
                if timelineItems.isEmpty { emptyState } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(timelineItems) { item in TimelineRow(item: item, isFirst: item.id == timelineItems.first?.id, isLast: item.id == timelineItems.last?.id) }
                    }.padding(.horizontal, 16)
                }
            }.padding(.top, 16)
        }.background(EchoTheme.darkBackground).navigationTitle("关系时间线").navigationBarTitleDisplayMode(.inline)
    }
    private var sentimentChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "chart.line.uptrend").foregroundStyle(EchoTheme.gradient); Text("情感趋势").font(EchoTheme.titleFont); Spacer() }.padding(.horizontal, 16)
            if notes.count >= 2 { SentimentChartView(notes: notes).frame(height: 120).padding(.horizontal, 16) } else { Text("至少需要2条笔记才能显示情感趋势").font(EchoTheme.captionFont).foregroundStyle(.secondary).padding(.horizontal, 16) }
        }
    }
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(title: "总互动", value: String(interactions.count), icon: "hand.wave")
            StatChip(title: "笔记", value: String(notes.count), icon: "note.text")
            StatChip(title: "天数", value: totalDays, icon: "calendar")
            StatChip(title: "渠道", value: String(Set(interactions.map { $0.type }).count), icon: "square.grid.2x2")
        }.padding(.horizontal, 16)
    }
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timeline.selection").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("还没有互动记录").font(EchoTheme.titleFont).foregroundStyle(.secondary)
            Text("开始联系 " + contact.givenName + " 后，这里会显示你们的关系时间线").font(EchoTheme.bodyFont).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.top, 60)
    }
    private var totalDays: String { guard let first = interactions.first else { return "0" }; return String(Calendar.current.dateComponents([.day], from: first.date, to: Date()).day ?? 0) }
}

private struct TimelineItem: Identifiable { let id = UUID(); let date: Date; let type: ItemType; enum ItemType { case interaction(Interaction); case note(Note) } }

private struct TimelineRow: View {
    let item: TimelineItem; let isFirst: Bool; let isLast: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) { if !isFirst { line }; node; if !isLast { line } }
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                switch item.type {
                case .interaction(let i): interactionContent(i)
                case .note(let n): noteContent(n)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    private var line: some View { Rectangle().fill(EchoTheme.accentColor.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity) }
    private var node: some View { Circle().fill(EchoTheme.gradient).frame(width: 12, height: 12).shadow(color: EchoTheme.accentColor.opacity(0.4), radius: 4) }
    private var dateText: String { let f = DateFormatter(); f.dateFormat = "M月d日 HH:mm"; return f.string(from: item.date) }
    private func interactionContent(_ i: Interaction) -> some View {
        HStack(spacing: 8) { Image(systemName: (InteractionType(rawValue: i.type)?.icon ?? "circle")).font(.system(size: 14)).foregroundStyle(EchoTheme.accentColor); Text((InteractionType(rawValue: i.type)?.label ?? "")).font(.system(size: 14, weight: .medium)); Spacer(); if !i.note.isEmpty { Text(i.note).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1) } }
    }
    private func noteContent(_ n: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Image(systemName: "note.text").font(.system(size: 12)).foregroundStyle(.secondary); Text("笔记").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }
            Text(n.content).font(.system(size: 14)).foregroundStyle(.primary).lineLimit(3)
        }
    }
}

private struct SentimentChartView: View {
    let notes: [Note]
    private var dataPoints: [(date: Date, score: Double)] { notes.sorted { $0.createdAt < $1.createdAt }.map { ($0.createdAt, sentimentScore($0.content)) } }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: geo.size.height / 2)); p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2)) }.stroke(EchoTheme.accentColor.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                if dataPoints.count >= 2 {
                    Path { p in
                        let step = geo.size.width / CGFloat(dataPoints.count - 1)
                        for (i, dp) in dataPoints.enumerated() { let x = CGFloat(i) * step; let y = geo.size.height * (1 - CGFloat(dp.score)); if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) } }
                    }.stroke(EchoTheme.gradient, style: StrokeStyle(lineWidth: 2.5))
                    ForEach(0..<dataPoints.count) { i in
                        let step = geo.size.width / CGFloat(max(dataPoints.count - 1, 1))
                        let x = CGFloat(i) * step; let y = geo.size.height * (1 - CGFloat(dataPoints[i].score))
                        Circle().fill(EchoTheme.accentColor).frame(width: 6, height: 6).position(x: x, y: y)
                    }
                }
            }
        }
    }
    private func sentimentScore(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore]); tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        if let s = Double(tag?.rawValue ?? "0") { return max(0, min(1, (s + 1.0) / 2.0)) }
        return 0.5
    }
}

private struct StatChip: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 14)).foregroundStyle(EchoTheme.gradient); Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.primary); Text(title).font(.system(size: 10)).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}