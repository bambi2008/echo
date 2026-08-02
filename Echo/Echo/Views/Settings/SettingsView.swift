import SwiftUI
import StoreKit

struct SettingsView: View {
    @State private var showAbout = false
    @State private var showPaywall = false
    @EnvironmentObject private var store: StoreManager
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                ScrollView {
                    VStack(spacing: EchoTheme.spacing16) {
                        planCard.echoAppear()
                        VStack(spacing: EchoTheme.spacing4) {
                            settingRow(icon: "link", label: "GitHub Repository", color: .blue) { if let url = URL(string: "https://github.com/bambi2008/echo") { UIApplication.shared.open(url) } }
                            settingRow(icon: "envelope", label: "Send Feedback", color: .orange) { if let url = URL(string: "mailto:bambi2008@users.noreply.github.com") { UIApplication.shared.open(url) } }
                            settingRow(icon: "info.circle", label: "About Echo", color: .gray) { showAbout = true }
                        }.padding(EchoTheme.spacing8).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).echoAppear(delay: 0.05)
                        VStack(alignment: .leading, spacing: EchoTheme.spacing12) {
                            HStack(spacing: EchoTheme.spacing8) { Image(systemName: "lock.fill").foregroundStyle(EchoTheme.success); Text("Your contacts stay on your device.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
                            HStack(spacing: EchoTheme.spacing8) { Image(systemName: "shield.fill").foregroundStyle(EchoTheme.success); Text("No cloud sync. No tracking. No ads.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
                        }.padding(EchoTheme.spacing16).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).echoAppear(delay: 0.1)
                        Text("念念不忘，必有回响").font(.caption).foregroundStyle(EchoTheme.textTertiary).padding(.top, EchoTheme.spacing8)
                    }.padding(.horizontal, EchoTheme.spacing16)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.large).alert("About Echo", isPresented: $showAbout) { Button("OK", role: .cancel) {} } message: { Text("Echo helps you stay in touch with the people who matter. All data stays on your device. v1.0") }.sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        }
    }
    private var planCard: some View {
        HStack(spacing: EchoTheme.spacing12) {
            Image(systemName: store.isPro ? "star.circle.fill" : "star.circle").font(.system(size: 28)).foregroundStyle(store.isPro ? EchoTheme.accent : EchoTheme.textTertiary).frame(width: 44, height: 44).background(store.isPro ? EchoTheme.accent.opacity(0.1) : Color.white.opacity(0.04)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) { Text(store.isPro ? "Echo Pro" : "Echo Personal").font(.headline).foregroundStyle(EchoTheme.textPrimary); Text(store.isPro ? "All features unlocked" : "Free · Limited features").font(.caption).foregroundStyle(EchoTheme.textTertiary) }
            Spacer()
            if !store.isPro { Button { EchoHaptics.light(); showPaywall = true } label: { Text("Upgrade").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).controlSize(.small) }
        }.padding(EchoTheme.spacing16).background(LinearGradient(colors: store.isPro ? [EchoTheme.accent.opacity(0.08), EchoTheme.bgCard] : [EchoTheme.bgCard, EchoTheme.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous).stroke(store.isPro ? EchoTheme.accent.opacity(0.15) : Color.white.opacity(0.06), lineWidth: 0.5))
    }
    private func settingRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button { EchoHaptics.selection(); action() } label: { HStack(spacing: EchoTheme.spacing12) { Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 28, height: 28).background(color.opacity(0.12)).clipShape(Circle()); Text(label).font(.subheadline).foregroundStyle(EchoTheme.textPrimary); Spacer(); Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(EchoTheme.textTertiary) }.padding(.horizontal, EchoTheme.spacing12).padding(.vertical, EchoTheme.spacing12) }.buttonStyle(.plain)
    }
}
