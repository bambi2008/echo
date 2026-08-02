import SwiftUI
struct EchoSpring {
    static let tap = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let card = Animation.spring(response: 0.45, dampingFraction: 0.75)
    static let page = Animation.spring(response: 0.55, dampingFraction: 0.8)
    static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let smooth = Animation.spring(response: 0.7, dampingFraction: 0.85)
    static let snap = Animation.spring(response: 0.25, dampingFraction: 0.9)
}
struct ScaleOnPress: ViewModifier { @State private var pressed = false; var scale: CGFloat = 0.96; func body(content: Content) -> some View { content.scaleEffect(pressed ? scale : 1).animation(EchoSpring.tap, value: pressed).onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { p in pressed = p }, perform: {}) } }
struct SpringAppear: ViewModifier { @State private var shown = false; var delay: Double = 0; func body(content: Content) -> some View { content.scaleEffect(shown ? 1 : 0.8).opacity(shown ? 1 : 0).onAppear { withAnimation(EchoSpring.card.delay(delay)) { shown = true } } } }
struct SlideUpAppear: ViewModifier { @State private var shown = false; var delay: Double = 0; func body(content: Content) -> some View { content.offset(y: shown ? 0 : 30).opacity(shown ? 1 : 0).onAppear { withAnimation(EchoSpring.card.delay(delay)) { shown = true } } } }
struct Heartbeat: ViewModifier { @State private var beat = false; var enabled: Bool = true; func body(content: Content) -> some View { content.scaleEffect(beat && enabled ? 1.08 : 1).animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: beat).onAppear { beat = true } } }
extension View { func scaleOnPress(scale: CGFloat = 0.96) -> some View { modifier(ScaleOnPress(scale: scale)) }; func springAppear(delay: Double = 0) -> some View { modifier(SpringAppear(delay: delay)) }; func slideUpAppear(delay: Double = 0) -> some View { modifier(SlideUpAppear(delay: delay)) }; func heartbeat(enabled: Bool = true) -> some View { modifier(Heartbeat(enabled: enabled)) } }