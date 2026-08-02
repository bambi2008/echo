import SwiftUI
struct MilestoneShareCard: View {
    let milestone: Milestone
    var body: some View {
        ZStack {
            LinearGradient(colors: milestone.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                HStack(spacing: 6) { Image(systemName: "wave.3.right").font(.system(size: 14, weight: .light)); Text("Echo").font(.system(size: 14, weight: .bold, design: .rounded)); Text("· Relationships that last").font(.system(size: 11)).opacity(0.7) }.foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                ZStack { Circle().fill(Color.white.opacity(0.15)).frame(width: 100, height: 100); Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).frame(width: 140, height: 140); Image(systemName: milestone.icon).font(.system(size: 44, weight: .medium)).foregroundStyle(Color.white) }
                Spacer().frame(height: 28)
                Text(milestone.title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
                Text(milestone.subtitle).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(0.85)).multilineTextAlignment(.center).padding(.horizontal, 36)
                Spacer().frame(height: 20)
                HStack(spacing: 24) { ForEach(0..<milestone.stats.count) { i in let s = milestone.stats[i]; VStack(spacing: 4) { Text(s.0).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Color.white); Text(s.1).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.7)) } } }
                Spacer()
                VStack(spacing: 12) { Text(milestone.ctaText).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.white.opacity(0.9)); HStack(spacing: 8) { Image(systemName: "wave.3.right").font(.system(size: 16, weight: .bold)); Text("echorelationships.app").font(.system(size: 14, weight: .medium, design: .rounded)) }.foregroundStyle(Color.white).padding(.horizontal, 20).padding(.vertical, 10).background(Color.white.opacity(0.15)).clipShape(Capsule()) }.padding(.bottom, 80)
            }
        }.frame(width: 360, height: 640).clipShape(RoundedRectangle(cornerRadius: 32))
    }
}
struct Milestone: Identifiable { let id = UUID(); let icon: String; let title: String; let subtitle: String; let stats: [(String, String)]; let gradientColors: [Color]; let ctaText: String
    static let streak30 = Milestone(icon: "flame.fill", title: "30 Day Streak!", subtitle: "You reached out to someone every day for 30 days. Your relationships are thriving.", stats: [("30", "Day Streak"), ("45", "People Reached")], gradientColors: [Color(hex: "FF6B35"), Color(hex: "F7931E"), Color(hex: "FFD23F")], ctaText: "I'm maintaining my relationships with Echo")
    static let reconnected = Milestone(icon: "arrow.triangle.2.circlepath", title: "Reconnected!", subtitle: "You reached out to someone you hadn't talked to in over 90 days.", stats: [("90", "Days Apart"), ("1", "Reconnection")], gradientColors: [Color(hex: "6B4DE6"), Color(hex: "9B59B6"), Color(hex: "E84393")], ctaText: "Echo helped me reconnect")
    static let champion = Milestone(icon: "crown.fill", title: "Relationship Champion", subtitle: "You've maintained healthy relationships with 10+ people this month.", stats: [("12", "Healthy"), ("0", "At Risk")], gradientColors: [Color(hex: "00B4D8"), Color(hex: "0077B6"), Color(hex: "03045E")], ctaText: "I'm a Relationship Champion on Echo")
    static let firstWeek = Milestone(icon: "sparkles", title: "First Week Complete!", subtitle: "You've taken the first step toward lasting relationships.", stats: [("7", "Days"), ("8", "Interactions")], gradientColors: [Color(hex: "1A1B4B"), Color(hex: "6B4DE6"), Color(hex: "00F5FF")], ctaText: "Building better relationships with Echo")
}
struct MilestoneOverlay: View { let milestone: Milestone; @Binding var isPresented: Bool; let onShare: (() -> Void)?; @State private var scale: CGFloat = 0.5; @State private var opacity: Double = 0
    var body: some View { ZStack { Color.black.opacity(0.7 * opacity).ignoresSafeArea(); VStack(spacing: 20) { MilestoneShareCard(milestone: milestone).scaleEffect(scale); HStack(spacing: 16) { Button { onShare?() } label: { HStack(spacing: 6) { Image(systemName: "square.and.arrow.up"); Text("分享") }.font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Color.white).padding(.horizontal, 24).padding(.vertical, 12).background(Color.white.opacity(0.2)).clipShape(Capsule()) }; Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isPresented = false } } label: { Text("关闭").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(0.7)).padding(.horizontal, 24).padding(.vertical, 12) } } } }.onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { scale = 1.0; opacity = 1.0 }; UINotificationFeedbackGenerator().notificationOccurred(.success) } } }
}