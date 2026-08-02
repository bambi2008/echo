import SwiftUI
import ActivityKit
struct ReachOutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable { var contactName: String; var contactInitial: String; var healthColor: String; var gapDays: Int; var elapsedTime: Double }
    var contactName: String
}
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<ReachOutAttributes>?
    func startActivity(for contact: EchoContact) {
        guard #available(iOS 16.2, *) else { return }
        stopActivity()
        let attrs = ReachOutAttributes(contactName: contact.givenName)
        let state = ReachOutAttributes.ContentState(contactName: contact.givenName, contactInitial: contact.givenName.prefix(1).uppercased(), healthColor: "00B4D8", gapDays: Int(Date().timeIntervalSince(contact.lastReachedOut ?? Date()) / 86400), elapsedTime: 0)
        do { currentActivity = try Activity.request(attributes: attrs, content: .init(state: state, staleDate: nil), pushType: nil) } catch {}
    }
    func stopActivity() { guard #available(iOS 16.2, *) else { return }; Task { await currentActivity?.end(nil, dismissalPolicy: .immediate); currentActivity = nil } }
}
struct ReachOutLiveActivityView: View {
    let context: ActivityViewContext<ReachOutAttributes>
    var body: some View {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) { ZStack { Circle().fill(Color(hex: context.state.healthColor).opacity(0.2)).frame(width: 36, height: 36); Text(context.state.contactInitial).font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: context.state.healthColor)) } }
            DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.gapDays)d ago").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }
            DynamicIslandExpandedRegion(.bottom) { HStack { Image(systemName: "wave.3.right").font(.system(size: 12)); Text("Reaching out to \(context.attributes.contactName)...").font(.system(size: 14, weight: .medium, design: .rounded)); Spacer(); Image(systemName: "message.fill").font(.system(size: 14)).foregroundStyle(.green) } }
        } compact: { HStack(spacing: 4) { Image(systemName: "wave.3.right").font(.system(size: 10)); Text(context.attributes.contactName).font(.system(size: 12, weight: .medium)) } }
        minimal: { Image(systemName: "wave.3.right").font(.system(size: 12)) }
    }
}
extension Color { init(hex: String) { let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v); let r, g, b: UInt64; (r, g, b) = (v >> 16, v >> 8 & 0xFF, v & 0xFF); self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) } }
}