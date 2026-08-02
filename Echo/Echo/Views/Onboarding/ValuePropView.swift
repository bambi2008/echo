import SwiftUI

struct ValuePropView: View {
    var onComplete: () -> Void
    @State private var currentIndex = 0
    private let features: [ValuePropItem] = [
        ValuePropItem(icon: "person.3.sequence.fill", title: "Import everyone in 10 seconds", subtitle: "One tap pulls in your contacts. Echo instantly shows who you've been neglecting.", gradient: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.35, blue: 0.85)]),
        ValuePropItem(icon: "wave.3.right.fill", title: "Reach out in one tap", subtitle: "Call, text, or email directly from Echo. Every interaction is logged automatically.", gradient: [Color(red: 0.20, green: 0.78, blue: 0.35), Color(red: 0.12, green: 0.65, blue: 0.28)]),
        ValuePropItem(icon: "clock.arrow.2.circlepath", title: "Echo remembers everything", subtitle: "When did you last talk? How often? Echo tracks it all — so you never lose touch.", gradient: [Color(red: 0.98, green: 0.69, blue: 0.25), Color(red: 0.90, green: 0.55, blue: 0.15)]),
        ValuePropItem(icon: "lock.fill", title: "100% private", subtitle: "Everything stays on your device. No cloud, no tracking, no ads. Just you and your people.", gradient: [Color(red: 0.65, green: 0.45, blue: 0.95), Color(red: 0.50, green: 0.30, blue: 0.85)])
    ]
    var body: some View {
        ZStack {
            EchoBackground()
            VStack(spacing: 0) {
                Spacer()
                TabView(selection: $currentIndex) { ForEach(Array(features.enumerated()), id: \.offset) { index, feature in featureCard(feature).tag(index).padding(.horizontal, 32) } }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 420)
                HStack(spacing: 8) { ForEach(0..<features.count, id: \.self) { i in Capsule().fill(i == currentIndex ? EchoTheme.accent : Color.white.opacity(0.15)).frame(width: i == currentIndex ? 24 : 8, height: 8).animation(.spring(duration: 0.3), value: currentIndex) } }.padding(.top, 16)
                Spacer()
                VStack(spacing: EchoTheme.spacing12) {
                    Button { EchoHaptics.medium(); onComplete() } label: { Text(currentIndex < features.count - 1 ? "Skip" : "Start Free Trial").font(.headline).frame(maxWidth: .infinity).frame(height: 54) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
                    if currentIndex < features.count - 1 { Button { withAnimation { currentIndex += 1 } } label: { Text("Next").font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textSecondary) } }
                }.padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }
    private func featureCard(_ item: ValuePropItem) -> some View {
        VStack(spacing: EchoTheme.spacing24) {
            Spacer()
            ZStack { Circle().fill(LinearGradient(colors: [item.gradient[0].opacity(0.15), item.gradient[1].opacity(0.05)], startPoint: .top, endPoint: .bottom)).frame(width: 120, height: 120); Image(systemName: item.icon).font(.system(size: 48, weight: .light)).foregroundStyle(LinearGradient(colors: item.gradient, startPoint: .top, endPoint: .bottom)) }
            VStack(spacing: EchoTheme.spacing12) { Text(item.title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary).multilineTextAlignment(.center); Text(item.subtitle).font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center).frame(maxWidth: 280) }
            Spacer()
        }
    }
}

private struct ValuePropItem { let icon: String; let title: String; let subtitle: String; let gradient: [Color] }
