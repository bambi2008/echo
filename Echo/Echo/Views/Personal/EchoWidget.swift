import WidgetKit
import SwiftUI
struct EchoWidgetEntry: TimelineEntry { let date: Date; let topContacts: [WidgetContact]; let streak: Int }
struct WidgetContact: Identifiable { let id: String; let name: String; let initial: String; let healthColor: String; let gapText: String }
struct EchoProvider: TimelineProvider {
    func placeholder(in c: Context) -> EchoWidgetEntry { EchoWidgetEntry(date: .now, topContacts: [WidgetContact(id: "1", name: "Sarah", initial: "S", healthColor: "00D9A3", gapText: "2d ago"), WidgetContact(id: "2", name: "Marcus", initial: "M", healthColor: "FF4E50", gapText: "45d ago"), WidgetContact(id: "3", name: "Yuki", initial: "Y", healthColor: "00B4D8", gapText: "8d ago")], streak: 12) }
    func getSnapshot(in c: Context, completion: @escaping (EchoWidgetEntry) -> Void) { completion(placeholder(in: c)) }
    func getTimeline(in c: Context, completion: @escaping (Timeline<EchoWidgetEntry>) -> Void) { let e = placeholder(in: c); completion(Timeline(entries: [e], policy: .after(.now.addingTimeInterval(3600)))) }
}
struct EchoWidgetView: View {
    var entry: EchoWidgetEntry
    var body: some View {
        ZStack { LinearGradient(colors: [Color(hex: "1A1B4B"), Color(hex: "2D1B6B")], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack { HStack(spacing: 4) { Image(systemName: "wave.3.right").font(.system(size: 10)); Text("Today's Echo").font(.system(size: 12, weight: .bold, design: .rounded)) }.foregroundStyle(Color.cyan); Spacer(); HStack(spacing: 3) { Image(systemName: "flame.fill").font(.system(size: 10)); Text("\(entry.streak)").font(.system(size: 12, weight: .bold, design: .rounded)) }.foregroundStyle(Color.orange) }
                ForEach(0..<min(entry.topContacts.count, 3)) { i in let c = entry.topContacts[i]; HStack(spacing: 8) { ZStack { Circle().fill(Color(hex: c.healthColor).opacity(0.2)).frame(width: 28, height: 28); Text(c.initial).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: c.healthColor)) }; VStack(alignment: .leading, spacing: 1) { Text(c.name).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white); Text(c.gapText).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3)) } }
                Spacer().frame(height: 2); Text("Tap to reach out").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }.padding(14)
        }.containerBackground(.clear, for: .widget)
    }
}
struct EchoWidget: Widget {
    let kind: String = "EchoWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoProvider()) { entry in EchoWidgetView(entry: entry).containerBackground(.clear, for: .widget) }
        .configurationDisplayName("Today's Echo").description("Your daily relationship reminders.").supportedFamilies([.systemSmall, .systemMedium])
    }
}
extension Color { init(hex: String) { let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v); let r, g, b: UInt64; (r, g, b) = (v >> 16, v >> 8 & 0xFF, v & 0xFF); self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
}