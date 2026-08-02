import SwiftUI

enum EchoTheme {
    static let bgPrimary = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let bgSecondary = Color(red: 0.06, green: 0.065, blue: 0.08)
    static let bgCard = Color.white.opacity(0.07)
    static let bgCardHover = Color.white.opacity(0.12)
    static let bgAccent = Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.12)
    static let accent = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let accentSoft = Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)
    static let overdue = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let radius12: CGFloat = 12
    static let radius14: CGFloat = 14
    static let radius16: CGFloat = 16
    static let radius20: CGFloat = 20
    static let radius24: CGFloat = 24
    static let cardShadow = (color: Color.black.opacity(0.3), radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 2)
}

enum EchoHaptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

struct EchoCardModifier: ViewModifier {
    var padding: CGFloat = EchoTheme.spacing16
    func body(content: Content) -> some View {
        content.padding(padding)
            .background(LinearGradient(colors: [EchoTheme.bgCard, EchoTheme.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            .shadow(color: EchoTheme.cardShadow.color, radius: EchoTheme.cardShadow.radius, x: EchoTheme.cardShadow.x, y: EchoTheme.cardShadow.y)
    }
}

extension View {
    func echoCard(padding: CGFloat = EchoTheme.spacing16) -> some View { modifier(EchoCardModifier(padding: padding)) }
    func echoAppear(delay: Double = 0) -> some View { modifier(EchoAppearModifier(delay: delay)) }
}

struct EchoAppearModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    func body(content: Content) -> some View {
        content.opacity(isVisible ? 1 : 0).offset(y: isVisible ? 0 : 16)
            .animation(.spring(duration: 0.4, bounce: 0.15).delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

struct EchoBackground: View {
    var body: some View {
        LinearGradient(colors: [EchoTheme.bgPrimary, Color(red: 0.02, green: 0.025, blue: 0.04)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}
