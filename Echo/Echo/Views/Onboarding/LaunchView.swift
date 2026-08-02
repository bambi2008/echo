import SwiftUI
struct LaunchView: View {
    @State private var animateWaves = false
    @State private var showText = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @Binding var hasLaunched: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A1B4B"), Color(hex: "2D1B6B"), Color(hex: "6B4DE6")], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    ForEach(0..<5) { i in
                        Circle().stroke(LinearGradient(colors: [Color.cyan.opacity(0.8 - Double(i) * 0.12), Color.purple.opacity(0.4 - Double(i) * 0.06)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 80 + CGFloat(i) * 50, height: 80 + CGFloat(i) * 50).scaleEffect(animateWaves ? 1.3 : 0.7).opacity(animateWaves ? 0 : 0.8).animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(Double(i) * 0.3), value: animateWaves)
                    }
                    ZStack {
                        Circle().fill(RadialGradient(colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.3)], center: .center, startRadius: 5, endRadius: 40)).frame(width: 72, height: 72).scaleEffect(pulseScale)
                        Image(systemName: "wave.3.right").font(.system(size: 32, weight: .light)).foregroundStyle(Color.white)
                    }
                }
                Spacer().frame(height: 40)
                VStack(spacing: 12) {
                    Text("Echo").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(Color.white).opacity(showText ? 1 : 0).offset(y: showText ? 0 : 20)
                    Text("Never lose touch again.").font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(Color.cyan.opacity(0.9)).opacity(showText ? 1 : 0).offset(y: showText ? 0 : 20)
                    Text("你的 AI 关系助手 — 记得每一个重要的人").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.6)).opacity(showButton ? 1 : 0)
                }
                Spacer()
                VStack(spacing: 16) {
                    Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { hasLaunched = true }; UISelectionFeedbackGenerator().selectionChanged() } label: {
                        HStack(spacing: 8) { Image(systemName: "sparkles"); Text("开始体验").font(.system(size: 17, weight: .semibold, design: .rounded)) }.foregroundStyle(Color(hex: "1A1B4B")).frame(maxWidth: .infinity).padding(.vertical, 18).background(LinearGradient(colors: [Color.cyan, Color.white], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.cyan.opacity(0.4), radius: 20, x: 0, y: 8)
                    }.opacity(showButton ? 1 : 0).offset(y: showButton ? 0 : 30)
                    Text("Product Hunt Launch · 100% On-Device AI").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.4)).opacity(showButton ? 1 : 0)
                }.padding(.horizontal, 32).padding(.bottom, 60)
            }
        }.onAppear {
            withAnimation(.easeOut(duration: 1.5)) { animateWaves = true }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) { showText = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) { showButton = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulseScale = 1.15 }
        }
    }
}