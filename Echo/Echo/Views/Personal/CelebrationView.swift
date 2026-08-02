import SwiftUI
struct CelebrationView: View {
    let type: CelebrationType; let onComplete: (() -> Void)?
    @State private var particles: [Particle] = []; @State private var animate = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.4 * (animate ? 1 : 0)).ignoresSafeArea().animation(.easeOut(duration: 0.3), value: animate)
            ZStack { ForEach(0..<particles.count) { i in let p = particles[i]; Circle().fill(p.color).frame(width: p.size, height: p.size).offset(x: p.x, y: p.y).opacity(p.opacity).rotationEffect(.degrees(p.rotation)) } }
            VStack(spacing: 24) {
                Spacer()
                ZStack { Circle().fill(type.color.opacity(0.2)).frame(width: 140, height: 140).scaleEffect(animate ? 1 : 0.3).opacity(animate ? 1 : 0); Circle().stroke(type.color, lineWidth: 3).frame(width: 110, height: 110).scaleEffect(animate ? 1 : 0.5).opacity(animate ? 0.6 : 0); Image(systemName: type.icon).font(.system(size: 56, weight: .ultraLight)).foregroundStyle(Color.white).scaleEffect(animate ? 1 : 0.3) }
                Text(type.title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color.white).scaleEffect(animate ? 1 : 0.5).opacity(animate ? 1 : 0)
                Text(type.subtitle).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.white.opacity(0.85)).multilineTextAlignment(.center).padding(.horizontal, 40).opacity(animate ? 1 : 0)
                Spacer()
                Button { onComplete?() } label: { Text("Awesome!").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(type.color).padding(.horizontal, 48).padding(.vertical, 14).background(Color.white.opacity(0.9)).clipShape(Capsule()).shadow(color: type.color.opacity(0.4), radius: 12) }.opacity(animate ? 1 : 0).padding(.bottom, 60)
            }
        }.onAppear { spawnParticles(); withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { animate = true }; let g = UIImpactFeedbackGenerator(style: .heavy); g.impactOccurred(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { g.impactOccurred(intensity: 0.6) }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { g.impactOccurred(intensity: 0.3) } }
    }
    private func spawnParticles() {
        let count = 30
        for i in 0..<count { let a = Double(i) / Double(count) * 2 * .pi; let d = CGFloat.random(in: 80...200); particles.append(Particle(x: 0, y: 0, targetX: cos(a) * d, targetY: sin(a) * d, color: type.particleColors.randomElement() ?? .white, size: CGFloat.random(in: 6...14), opacity: 1.0, rotation: 0)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeOut(duration: 1.2)) { for i in 0..<particles.count { particles[i].x = particles[i].targetX; particles[i].y = particles[i].targetY; particles[i].opacity = 0; particles[i].rotation = Double.random(in: 0...360) } } }
    }
}
struct Particle: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var targetX: CGFloat; var targetY: CGFloat; var color: Color; var size: CGFloat; var opacity: Double; var rotation: Double }
enum CelebrationType {
    case achievementUnlock(title: String, subtitle: String); case milestoneReached(title: String, subtitle: String); case streakUnlocked(title: String, subtitle: String)
    var icon: String { switch self { case .achievementUnlock: "trophy.fill"; case .milestoneReached: "star.fill"; case .streakUnlocked: "flame.fill" } }
    var title: String { switch self { case .achievementUnlock(let t, _): t; case .milestoneReached(let t, _): t; case .streakUnlocked(let t, _): t } }
    var subtitle: String { switch self { case .achievementUnlock(_, let s): s; case .milestoneReached(_, let s): s; case .streakUnlocked(_, let s): s } }
    var color: Color { switch self { case .achievementUnlock: Color(hex: "FFD23F"); case .milestoneReached: Color(hex: "6B4DE6"); case .streakUnlocked: Color(hex: "FF6B35") } }
    var particleColors: [Color] { switch self { case .achievementUnlock: [.yellow, .orange, .white, .cyan]; case .milestoneReached: [.purple, .cyan, .white, .pink]; case .streakUnlocked: [.orange, .red, .yellow, .white] } }
}
struct CelebrationModifier: ViewModifier { @Binding var celebration: CelebrationType?; func body(content: Content) -> some View { ZStack { content; if let c = celebration { CelebrationView(type: c, onComplete: { withAnimation(.easeOut(duration: 0.3)) { celebration = nil } }).transition(.opacity) } } } }
extension View { func celebrationOverlay(celebration: Binding<CelebrationType?>) -> some View { modifier(CelebrationModifier(celebration: celebration)) } }