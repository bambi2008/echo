import SwiftUI
struct MagicMomentView: View {
    @Binding var hasLaunched: Bool
    @State private var stars: [Star] = []
    @State private var showStars = false
    @State private var showLines = false
    @State private var showText = false
    @State private var showButtons = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "030014"), Color(hex: "0A0E2E"), Color(hex: "1A1B4B")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Canvas { ctx, _ in for _ in 0..<80 { let x = CGFloat.random(in: 0...390); let y = CGFloat.random(in: 0...844); let s = CGFloat.random(in: 0.5...1.5); ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(Double.random(in: 0.1...0.4)))) } }.ignoresSafeArea()
            Canvas { ctx, _ in guard showLines else { return }; let vs = stars.filter { $0.appeared }; for i in 0..<vs.count { let s1 = vs[i]; for j in (i+1)..<vs.count { let s2 = vs[j]; let d = hypot(s1.pos.x - s2.pos.x, s1.pos.y - s2.pos.y); if d < 120 { let o = 1.0 - d / 120; let p = Path { pp in pp.move(to: s1.pos); pp.addLine(to: s2.pos) }; ctx.stroke(p, with: .color(.cyan.opacity(o * 0.3)), lineWidth: 0.5) } } } }.ignoresSafeArea().opacity(showLines ? 1 : 0).animation(.easeIn(duration: 1.5), value: showLines)
            ForEach(0..<stars.count) { i in let s = stars[i]; Circle().fill(s.color).frame(width: s.size, height: s.size).shadow(color: s.color, radius: s.size * 2).position(x: s.pos.x, y: s.pos.y).scaleEffect(s.appeared ? 1 : 0).opacity(s.appeared ? 1 : 0).animation(.spring(response: 0.6, dampingFraction: 0.6).delay(s.delay), value: showStars) }.ignoresSafeArea()
            VStack {
                Spacer().frame(height: 100)
                if showText { VStack(spacing: 10) { Text("Every relationship is a star.").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Color.white); Text("Some are shining. Some are fading.").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.cyan.opacity(0.85)); Text("Echo helps you keep them all bright.").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.white.opacity(0.7)) }.multilineTextAlignment(.center).transition(.opacity.combined(with: .move(edge: .bottom))) }
                Spacer()
                if showButtons { VStack(spacing: 14) { Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { hasLaunched = true } } label: { HStack(spacing: 8) { Image(systemName: "play.fill"); Text("体验 Demo").font(.system(size: 17, weight: .semibold, design: .rounded)) }.foregroundStyle(Color(hex: "030014")).frame(maxWidth: .infinity).padding(.vertical, 18).background(LinearGradient(colors: [Color.cyan, Color.white], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.cyan.opacity(0.4), radius: 20, x: 0, y: 8) }; Button { UISelectionFeedbackGenerator().selectionChanged(); withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { hasLaunched = true } } label: { Text("注册新账号").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(0.7)) } }.padding(.horizontal, 32).padding(.bottom, 60).transition(.opacity.combined(with: .move(edge: .bottom))) }
            }
        }.onAppear { generateStars() }
    }
    private func generateStars() {
        let colors: [Color] = [Color(hex: "00D9A3"), Color(hex: "00B4D8"), Color(hex: "FFB347"), Color(hex: "FF4E50"), Color(hex: "00D9A3"), Color(hex: "00B4D8")]
        for i in 0..<15 { let a = Double(i) / 15 * 2 * .pi; let r = CGFloat.random(in: 80...180); let c = CGPoint(x: 195, y: 350); stars.append(Star(pos: CGPoint(x: c.x + cos(a) * r + CGFloat.random(in: -30...30), y: c.y + sin(a) * r + CGFloat.random(in: -30...30)), color: colors[i % colors.count], size: CGFloat.random(in: 6...14), delay: Double(i) * 0.08, appeared: false)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showStars = true; for i in 0..<stars.count { stars[i].appeared = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showLines = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation(.spring) { showText = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { withAnimation(.spring) { showButtons = true } }
    }
}
struct Star: Identifiable { let id = UUID(); var pos: CGPoint; var color: Color; var size: CGFloat; var delay: Double; var appeared: Bool }