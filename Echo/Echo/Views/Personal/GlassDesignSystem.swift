import SwiftUI
struct GlassDesignSystem {
    static func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View { content().padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1)).shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6) }
    static func glassButton<Label: View>(@ViewBuilder label: () -> Label) -> some View { label().padding(.horizontal, 24).padding(.vertical, 12).background(.ultraThinMaterial).clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)).shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4) }
    static func glowingAvatar(initial: String, color: Color, size: CGFloat = 50) -> some View { ZStack { Circle().fill(color.opacity(0.2)).frame(width: size, height: size); Circle().stroke(color.opacity(0.3), lineWidth: 1.5).frame(width: size, height: size).shadow(color: color.opacity(0.4), radius: size * 0.3); Text(initial).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(color) } }
}
struct Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func triple() { let g = UIImpactFeedbackGenerator(style: .heavy); g.impactOccurred(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { g.impactOccurred(intensity: 0.6) }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { g.impactOccurred(intensity: 0.3) } }
}
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? scale : 1).animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed) }
}
extension ButtonStyle where Self == PressableStyle { static var pressable: PressableStyle { PressableStyle() } }
struct FloatingTabBar: View {
    @Binding var selectedTab: Int; let onReach: () -> Void
    var body: some View {
        VStack { Spacer(); HStack(spacing: 0) { tabItem(icon: "person.3.sequence", label: "Echo", index: 0); Spacer(); tabItem(icon: "person.2.circle", label: "All", index: 1); Spacer(); Button { Haptics.medium(); onReach() } label: { ZStack { Circle().fill(LinearGradient(colors: [EchoTheme.accentColor, Color(hex: "00F5FF")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 56, height: 56).shadow(color: EchoTheme.accentColor.opacity(0.5), radius: 12, x: 0, y: 4); Image(systemName: "wave.3.right").font(.system(size: 22, weight: .medium)).foregroundStyle(.white) } }.buttonStyle(.pressable).offset(y: -20); Spacer(); tabItem(icon: "trophy", label: "Awards", index: 2); Spacer(); tabItem(icon: "gearshape", label: "Settings", index: 3) }.padding(.horizontal, 16).padding(.vertical, 12).padding(.bottom, 2).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 16).padding(.bottom, 2).shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8) }
    }
    private func tabItem(icon: String, label: String, index: Int) -> some View { Button { Haptics.selection(); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index } } label: { VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular)).foregroundStyle(selectedTab == index ? EchoTheme.accentColor : .secondary).scaleEffect(selectedTab == index ? 1.1 : 1); Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(selectedTab == index ? EchoTheme.accentColor : .secondary) }.frame(width: 56, height: 44) }.buttonStyle(.pressable) }
}