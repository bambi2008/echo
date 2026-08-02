import SwiftUI
struct YearInReviewView: View {
    let contacts: [EchoContact]
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0; @State private var showShare = false
    private let pages: [ReviewPage] = [
        ReviewPage(icon: "sparkles", title: "Your Year with Echo", subtitle: "Let's look back at the relationships you nurtured.", stat: nil, statLabel: nil, gradient: [Color(hex: "1A1B4B"), Color(hex: "6B4DE6"), Color(hex: "00F5FF")]),
        ReviewPage(icon: "person.3.fill", title: "People in Your Echo", subtitle: "You kept track of who matters.", stat: "12", statLabel: "Contacts in Echo Layer", gradient: [Color(hex: "6B4DE6"), Color(hex: "9B59B6")]),
        ReviewPage(icon: "hand.wave.fill", title: "You Showed Up", subtitle: "Every message, call, coffee counted.", stat: "87", statLabel: "Total Interactions", gradient: [Color(hex: "00B4D8"), Color(hex: "0077B6")]),
        ReviewPage(icon: "flame.fill", title: "Your Longest Streak", subtitle: "You reached out every single day for...", stat: "23", statLabel: "Days in a Row", gradient: [Color(hex: "FF6B35"), Color(hex: "FF4E50"), Color(hex: "FFD23F")]),
        ReviewPage(icon: "arrow.triangle.2.circlepath", title: "You Reconnected", subtitle: "You reached out after months apart. That takes courage.", stat: "5", statLabel: "Reconnections After 90+ Days", gradient: [Color(hex: "9B59B6"), Color(hex: "E84393")]),
        ReviewPage(icon: "heart.fill", title: "Relationships That Thrived", subtitle: "These grew stronger because you showed up.", stat: "8", statLabel: "Healthy Relationships", gradient: [Color(hex: "00D9A3"), Color(hex: "00B4D8"), Color(hex: "6B4DE6")]),
        ReviewPage(icon: "crown.fill", title: "Your Relationship DNA", subtitle: "You're someone who remembers. And that's rare.", stat: nil, statLabel: nil, gradient: [Color(hex: "1A1B4B"), Color(hex: "6B4DE6"), Color(hex: "00F5FF")]),
    ]
    var body: some View {
        ZStack {
            LinearGradient(colors: pages[currentPage].gradient, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea().animation(.easeInOut(duration: 0.6), value: currentPage)
            VStack(spacing: 0) {
                HStack(spacing: 6) { ForEach(0..<pages.count) { i in Capsule().fill(Color.white.opacity(i == currentPage ? 1 : 0.3)).frame(height: 3).frame(maxWidth: i == currentPage ? 28 : 14).animation(.spring(response: 0.4), value: currentPage) } }.padding(.top, 60).padding(.horizontal, 24)
                Spacer()
                TabView(selection: $currentPage) { ForEach(0..<pages.count) { i in ReviewPageView(page: pages[i]).tag(i) } }.tabViewStyle(.page(indexDisplayMode: .never))
                Spacer()
                HStack(spacing: 16) {
                    if currentPage < pages.count - 1 { Button { withAnimation { currentPage += 1 } } label: { Text("Skip").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.white.opacity(0.5)) } }
                    Button { if currentPage < pages.count - 1 { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentPage += 1 }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() } else { showShare = true; UINotificationFeedbackGenerator().notificationOccurred(.success) } } label: { HStack(spacing: 8) { if currentPage == pages.count - 1 { Image(systemName: "square.and.arrow.up") }; Text(currentPage == pages.count - 1 ? "Share My Year" : "Continue") }.font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(Color.white).padding(.horizontal, 32).padding(.vertical, 16).background(Color.white.opacity(0.2)).clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)) }
                    if currentPage == pages.count - 1 { Button { dismiss() } label: { Text("Done").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.white.opacity(0.7)) } }
                }.padding(.bottom, 50).animation(.easeInOut, value: currentPage)
            }
        }.sheet(isPresented: $showShare) { YearInReviewShareCard() }
    }
}
struct ReviewPage: Identifiable { let id = UUID(); let icon: String; let title: String; let subtitle: String; let stat: String?; let statLabel: String?; let gradient: [Color] }
struct ReviewPageView: View {
    let page: ReviewPage; @State private var animateIn = false
    var body: some View {
        VStack(spacing: 28) {
            ZStack { Circle().fill(Color.white.opacity(0.05)).frame(width: 200, height: 200).scaleEffect(animateIn ? 1 : 0.5); Circle().stroke(Color.white.opacity(0.1), lineWidth: 1).frame(width: 160, height: 160).scaleEffect(animateIn ? 1 : 0.3); Image(systemName: page.icon).font(.system(size: 64, weight: .ultraLight)).foregroundStyle(Color.white).scaleEffect(animateIn ? 1 : 0.3).opacity(animateIn ? 1 : 0) }
            VStack(spacing: 16) {
                Text(page.title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color.white).multilineTextAlignment(.center).opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 20)
                if let stat = page.stat { Text(stat).font(.system(size: 72, weight: .heavy, design: .rounded)).foregroundStyle(Color.white).shadow(color: Color.white.opacity(0.3), radius: 20).scaleEffect(animateIn ? 1 : 0.3).opacity(animateIn ? 1 : 0); if let l = page.statLabel { Text(l).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(0.7)).opacity(animateIn ? 1 : 0) } }
                Text(page.subtitle).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.white.opacity(0.85)).multilineTextAlignment(.center).padding(.horizontal, 40).opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 15)
            }
        }.onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) { animateIn = true } }
    }
}
struct YearInReviewShareCard: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A1B4B"), Color(hex: "6B4DE6"), Color(hex: "00F5FF")], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer().frame(height: 40); HStack(spacing: 6) { Image(systemName: "wave.3.right").font(.system(size: 14, weight: .light)); Text("Echo · Year in Review").font(.system(size: 14, weight: .bold, design: .rounded)) }.foregroundStyle(Color.white.opacity(0.6)); Spacer()
                VStack(spacing: 12) { Text("My Year").font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundStyle(Color.white); HStack(spacing: 32) { VStack(spacing: 4) { Text("12").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.white); Text("People").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.7)) }; VStack(spacing: 4) { Text("87").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.white); Text("Interactions").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.7)) }; VStack(spacing: 4) { Text("23").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.white); Text("Day Streak").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.7)) } } }; Spacer()
                VStack(spacing: 12) { Text("I remembered the people who matter.").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(Color.white.opacity(0.9)); HStack(spacing: 8) { Image(systemName: "wave.3.right").font(.system(size: 14, weight: .bold)); Text("echorelationships.app").font(.system(size: 13, weight: .medium, design: .rounded)) }.foregroundStyle(Color.white).padding(.horizontal, 20).padding(.vertical, 10).background(Color.white.opacity(0.15)).clipShape(Capsule()) }.padding(.bottom, 60)
            }.frame(width: 360, height: 640).clipShape(RoundedRectangle(cornerRadius: 32))
            VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(Color.white.opacity(0.6)) }.padding() }; Spacer() }
        }
    }
}