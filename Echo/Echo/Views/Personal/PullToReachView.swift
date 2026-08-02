import SwiftUI
struct PullToReachModifier: ViewModifier {
    @Binding var pullDistance: CGFloat; let onTrigger: () -> Void; private let threshold: CGFloat = 120
    func body(content: Content) -> some View { content.background(GeometryReader { geo in Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("pullToReach")).minY) }).onPreferenceChange(ScrollOffsetKey.self) { value in pullDistance = max(0, value); if value > threshold { Haptics.light(); onTrigger() } } }
}
struct ScrollOffsetKey: PreferenceKey { static var defaultValue: CGFloat = 0; static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() } }
struct PullReachHint: View {
    let pullDistance: CGFloat; let suggestion: String?
    var body: some View {
        VStack(spacing: 6) { if pullDistance > 10 { Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(EchoTheme.accentColor).rotationEffect(.degrees(pullDistance * 1.5)).animation(.easeInOut, value: pullDistance); if pullDistance > 60 && suggestion != nil { Text("松手让 Echo 建议").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary).transition(.opacity) } } }.frame(height: min(pullDistance, 80)).opacity(min(pullDistance / 60, 1))
    }
}
extension View { func pullToReach(distance: Binding<CGFloat>, onTrigger: @escaping () -> Void) -> some View { modifier(PullToReachModifier(pullDistance: distance, onTrigger: onTrigger)) } }