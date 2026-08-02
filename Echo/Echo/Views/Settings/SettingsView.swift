import SwiftUI
import StoreKit
struct SettingsView: View {
    @State private var showAbout = false; @State private var showPaywall = false; @State private var showYearInReview = false; @State private var showFoundersNote = false; @State private var showAIChat = false
    @EnvironmentObject private var store: StoreManager; @EnvironmentObject private var auth: AuthManager; @EnvironmentObject private var trial: TrialManager
    @Query private var contacts: [EchoContact]
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        planCard; accountCard
                        VStack(spacing: 4) {
                            settingRow("sparkles", "Year in Review", .purple) { showYearInReview = true }
                            settingRow("wave.3.right", "Chat with Echo AI", .cyan) { showAIChat = true }
                            settingRow("link", "GitHub Repository", .blue) { if let u = URL(string: "https://github.com/bambi2008/echo") { UIApplication.shared.open(u) } }
                            settingRow("envelope", "Send Feedback", .orange) { if let u = URL(string: "mailto:bambi2008@users.noreply.github.com") { UIApplication.shared.open(u) } }
                            settingRow("person.crop.circle.badge.questionmark", "About Echo", .gray) { showAbout = true }
                        }.padding(8).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) { Image(systemName: "lock.fill").foregroundStyle(EchoTheme.success); Text("Your contacts stay on your device.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
                            HStack(spacing: 8) { Image(systemName: "shield.fill").foregroundStyle(EchoTheme.success); Text("No cloud sync. No tracking. No ads.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
                        }.padding(16).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: 16))
                        Text("念念不忘，必有回响").font(.caption).foregroundStyle(EchoTheme.textTertiary).padding(.top, 8)
                    }.padding(.horizontal, 16)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showYearInReview) { YearInReviewView(contacts: contacts) }
            .sheet(isPresented: $showAIChat) { AIChatView(contacts: contacts) }
            .sheet(isPresented: $showFoundersNote) { FoundersNoteView() }
            .alert("About Echo", isPresented: $showAbout) { Button("OK", role: .cancel) {} } message: { Text("Echo helps you stay in touch with the people who matter. All data stays on your device. v1.0") }
            .sheet(isPresented: $showPaywall) { PaywallView { } }
        }
    }
    private var planCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isPro ? "star.circle.fill" : "star.circle").font(.system(size: 28)).foregroundStyle(store.isPro ? EchoTheme.accent : EchoTheme.textTertiary).frame(width: 44, height: 44).background(store.isPro ? EchoTheme.accent.opacity(0.1) : Color.white.opacity(0.04)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) { Text(store.isPro ? "Echo Pro" : trial.isInTrial ? "Free Trial" : "Echo Personal").font(.headline).foregroundStyle(EchoTheme.textPrimary); if trial.isInTrial { Text("\(trial.daysRemaining) days left in trial").font(.caption).foregroundStyle(EchoTheme.overdue) } else { Text(store.isPro ? "All features unlocked" : "Free · Limited features").font(.caption).foregroundStyle(EchoTheme.textTertiary) } }
            Spacer()
            if !store.isPro { Button { EchoHaptics.light(); showPaywall = true } label: { Text(trial.isInTrial ? "Manage" : "Upgrade").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).controlSize(.small) }
        }.padding(16).background(LinearGradient(colors: store.isPro ? [EchoTheme.accent.opacity(0.08), EchoTheme.bgCard] : trial.isInTrial ? [EchoTheme.overdue.opacity(0.08), EchoTheme.bgCard] : [EchoTheme.bgCard, EchoTheme.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var accountCard: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(EchoTheme.accent.opacity(0.1)).frame(width: 40, height: 40); Image(systemName: "person.crop.circle.fill").font(.system(size: 18)).foregroundStyle(EchoTheme.accent) }
            VStack(alignment: .leading, spacing: 2) { if let user = auth.currentUser { Text(user.email).font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textPrimary).lineLimit(1); HStack(spacing: 4) { Image(systemName: user.provider == .apple ? "applelogo" : user.provider == .google ? "g.circle" : "envelope").font(.system(size: 10)); Text("via \(user.provider.label)") }.font(.caption2).foregroundStyle(EchoTheme.textTertiary) } else { Text("Not signed in").font(.subheadline).foregroundStyle(EchoTheme.textTertiary) } }
            Spacer()
            if auth.isLoggedIn { Button { EchoHaptics.selection(); auth.logout() } label: { Text("Sign Out").font(.caption).foregroundStyle(EchoTheme.overdue) } }
        }.padding(16).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func settingRow(_ icon: String, _ label: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button { EchoHaptics.selection(); action() } label: { HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 28, height: 28).background(color.opacity(0.12)).clipShape(Circle()); Text(label).font(.subheadline).foregroundStyle(EchoTheme.textPrimary); Spacer(); Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(EchoTheme.textTertiary) }.padding(.horizontal, 12).padding(.vertical, 12) }.buttonStyle(.plain)
    }
}