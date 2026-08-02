import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager
    @State private var purchasing = false
    @State private var purchaseError: String?
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                ScrollView {
                    VStack(spacing: EchoTheme.spacing24) {
                        VStack(spacing: EchoTheme.spacing12) {
                            ZStack { Circle().fill(LinearGradient(colors: [EchoTheme.accent.opacity(0.15), EchoTheme.accent.opacity(0.05)], startPoint: .top, endPoint: .bottom)).frame(width: 72, height: 72); Image(systemName: "sparkles").font(.system(size: 30, weight: .light)).foregroundStyle(EchoTheme.accent) }
                            Text("Echo Pro").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary)
                            Text("Never lose touch with who matters.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary)
                        }.padding(.top, EchoTheme.spacing24).echoAppear()
                        VStack(alignment: .leading, spacing: EchoTheme.spacing12) {
                            featureRow(text: "Unlimited Echo Layer contacts"); featureRow(text: "Full interaction history"); featureRow(text: "Unlimited notes per contact"); featureRow(text: "AI interaction frequency analysis"); featureRow(text: "Smart rhythm alerts"); featureRow(text: "Relationship health insights"); featureRow(text: "Conversation starter suggestions"); featureRow(text: "Custom themes & app icon")
                        }.padding(.horizontal, EchoTheme.spacing24).echoAppear(delay: 0.1)
                        VStack(spacing: EchoTheme.spacing12) {
                            if store.isLoading { ProgressView().tint(EchoTheme.accent) }
                            else { ForEach(store.products, id: \.id) { product in productCard(product).echoAppear(delay: 0.15) } }
                            if store.products.isEmpty { Text("Products will appear after App Store Connect setup").font(.caption).foregroundStyle(EchoTheme.textTertiary).multilineTextAlignment(.center).padding(.horizontal, 32) }
                            if let error = purchaseError { Text(error).font(.caption).foregroundStyle(EchoTheme.overdue) }
                        }.padding(.horizontal, EchoTheme.spacing24)
                        Button { EchoHaptics.light(); Task { await store.restorePurchases() } } label: { Text("Restore Purchases").font(.subheadline).foregroundStyle(EchoTheme.textTertiary) }.padding(.bottom, EchoTheme.spacing8)
                    }.padding(.bottom, EchoTheme.spacing32)
                }
            }.navigationTitle("Upgrade").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.tint(EchoTheme.textSecondary) } }
        }
    }
    private func featureRow(text: String) -> some View {
        HStack(spacing: EchoTheme.spacing12) { Image(systemName: "checkmark.circle.fill").foregroundStyle(EchoTheme.accent).frame(width: 22); Text(text).font(.subheadline).foregroundStyle(EchoTheme.textPrimary); Spacer() }
    }
    private func productCard(_ product: Product) -> some View {
        Button { EchoHaptics.light(); Task { purchasing = true; purchaseError = nil; do { let success = try await store.purchase(product); if success { dismiss() } } catch { purchaseError = error.localizedDescription }; purchasing = false } } label: {
            HStack { VStack(alignment: .leading, spacing: 4) { Text(product.displayName).font(.headline).foregroundStyle(EchoTheme.textPrimary); Text(product.description).font(.caption).foregroundStyle(EchoTheme.textTertiary).lineLimit(1) }; Spacer(); Text(product.displayPrice).font(.title3.bold()).foregroundStyle(EchoTheme.accent) }.padding(EchoTheme.spacing16).background(LinearGradient(colors: [EchoTheme.accent.opacity(0.08), EchoTheme.bgCard], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(EchoTheme.accent.opacity(0.2), lineWidth: 1))
        }.buttonStyle(.plain).disabled(purchasing).opacity(purchasing ? 0.6 : 1.0)
    }
}
