import SwiftUI
import StoreKit

struct PaywallView: View {
    var onSubscribed: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager
    @StateObject private var trial = TrialManager.shared
    @State private var purchasing = false
    @State private var purchaseError: String?
    @State private var selectedProductID: String?
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                ScrollView {
                    VStack(spacing: EchoTheme.spacing24) {
                        HStack(spacing: 8) { Image(systemName: "gift.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.white); Text("3-Day Free Trial").font(.subheadline.weight(.semibold)).foregroundStyle(.white) }.padding(.horizontal, 20).padding(.vertical, 10).background(LinearGradient(colors: [EchoTheme.accent, Color(red: 0.15, green: 0.35, blue: 0.85)], startPoint: .leading, endPoint: .trailing)).clipShape(Capsule()).shadow(color: EchoTheme.accent.opacity(0.3), radius: 8, y: 4).echoAppear().padding(.top, 32)
                        VStack(spacing: EchoTheme.spacing12) { ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 72, height: 72); Image(systemName: "sparkles").font(.system(size: 30, weight: .light)).foregroundStyle(EchoTheme.accent) }; Text("Echo Pro").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary); Text("Never lose touch with who matters.\nCancel anytime within 3 days — no charge.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }.echoAppear(delay: 0.05)
                        VStack(alignment: .leading, spacing: EchoTheme.spacing12) { featureRow(icon: "person.3.sequence.fill", text: "Unlimited Echo Layer contacts"); featureRow(icon: "clock.arrow.2.circlepath", text: "Full interaction history (no 30-day limit)"); featureRow(icon: "note.text.fill", text: "Unlimited notes per contact"); featureRow(icon: "flame.fill", text: "Weekly streaks & milestone sharing"); featureRow(icon: "chart.bar.fill", text: "Relationship health insights"); featureRow(icon: "lock.fill", text: "Priority support & early features") }.padding(EchoTheme.spacing20).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).echoAppear(delay: 0.1)
                        VStack(spacing: EchoTheme.spacing12) { if store.isLoading { ProgressView().tint(EchoTheme.accent).frame(height: 80) } else if store.products.isEmpty { fallbackPricing } else { ForEach(store.products, id: \.id) { product in productCard(product).echoAppear(delay: 0.15) } }; if let error = purchaseError { Text(error).font(.caption).foregroundStyle(EchoTheme.overdue) } }.padding(.horizontal, 32)
                        VStack(spacing: EchoTheme.spacing12) {
                            Button { EchoHaptics.medium(); Task { await handlePurchase() } } label: { if purchasing { HStack(spacing: 8) { ProgressView().tint(.white); Text("Starting trial…") }.font(.headline).frame(maxWidth: .infinity).frame(height: 56) } else { VStack(spacing: 2) { Text("Start 3-Day Free Trial").font(.headline); Text("Cancel anytime · No charge for 3 days").font(.caption2) }.frame(maxWidth: .infinity).frame(height: 56) } }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).disabled(purchasing).padding(.horizontal, 32)
                            Button { EchoHaptics.light(); Task { await store.restorePurchases() } } label: { Text("Restore Purchases").font(.subheadline).foregroundStyle(EchoTheme.textTertiary) }
                        }.echoAppear(delay: 0.2)
                        VStack(spacing: 4) { Text("3-day free trial, then auto-renews unless cancelled.").font(.caption2).foregroundStyle(EchoTheme.textTertiary); Text("Manage or cancel anytime in Settings → Apple ID → Subscriptions.").font(.caption2).foregroundStyle(EchoTheme.textTertiary) }.multilineTextAlignment(.center).padding(.horizontal, 32)
                    }.padding(.bottom, 48)
                }
            }.navigationTitle("").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { if trial.isInTrial { Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundStyle(EchoTheme.textTertiary) } } } }
        }
    }
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: EchoTheme.spacing12) { ZStack { Circle().fill(EchoTheme.accent.opacity(0.12)).frame(width: 32, height: 32); Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(EchoTheme.accent) }; Text(text).font(.subheadline).foregroundStyle(EchoTheme.textPrimary); Spacer(); Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(EchoTheme.success) }
    }
    private func productCard(_ product: Product) -> some View {
        let isYearly = product.id == StoreManager.yearlyProID; let isSelected = selectedProductID == product.id
        return Button { EchoHaptics.selection(); withAnimation(.spring(duration: 0.2)) { selectedProductID = product.id } } label: { HStack(spacing: EchoTheme.spacing12) { ZStack { Circle().stroke(isSelected ? EchoTheme.accent : Color.white.opacity(0.2), lineWidth: 2).frame(width: 24, height: 24); if isSelected { Circle().fill(EchoTheme.accent).frame(width: 12, height: 12) } }; VStack(alignment: .leading, spacing: 4) { Text(product.displayName).font(.headline).foregroundStyle(EchoTheme.textPrimary); Text(product.description).font(.caption).foregroundStyle(EchoTheme.textTertiary).lineLimit(1) }; Spacer(); VStack(alignment: .trailing, spacing: 2) { Text(product.displayPrice).font(.title3.bold()).foregroundStyle(EchoTheme.textPrimary); if isYearly { Text("Save 40%").font(.caption2.weight(.semibold)).foregroundStyle(EchoTheme.success) } } }.padding(EchoTheme.spacing16).background(isSelected ? LinearGradient(colors: [EchoTheme.accent.opacity(0.1), EchoTheme.bgCard], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [EchoTheme.bgCard, EchoTheme.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(isSelected ? EchoTheme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)) }.buttonStyle(.plain)
    }
    private var fallbackPricing: some View {
        VStack(spacing: EchoTheme.spacing12) {
            pricingCard(title: "Monthly", price: "$4.99", subtitle: "Billed monthly", isBestValue: false, id: StoreManager.monthlyProID)
            pricingCard(title: "Yearly", price: "$29.99", subtitle: "Billed annually · Save 50%", isBestValue: true, id: StoreManager.yearlyProID)
            Text("Products will sync from App Store Connect").font(.caption2).foregroundStyle(EchoTheme.textTertiary)
        }
    }
    private func pricingCard(title: String, price: String, subtitle: String, isBestValue: Bool, id: String) -> some View {
        let isSelected = selectedProductID == id || (selectedProductID == nil && isBestValue)
        return Button { EchoHaptics.selection(); withAnimation { selectedProductID = id } } label: { HStack { ZStack { Circle().stroke(isSelected ? EchoTheme.accent : Color.white.opacity(0.2), lineWidth: 2).frame(width: 24, height: 24); if isSelected { Circle().fill(EchoTheme.accent).frame(width: 12, height: 12) } }; VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(EchoTheme.textPrimary); Text(subtitle).font(.caption).foregroundStyle(EchoTheme.textTertiary) }; Spacer(); Text(price).font(.title3.bold()).foregroundStyle(EchoTheme.textPrimary) }.padding(EchoTheme.spacing16).background(isSelected ? EchoTheme.accent.opacity(0.1) : EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(isSelected ? EchoTheme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)) }.buttonStyle(.plain)
    }
    private func handlePurchase() async {
        purchasing = true; purchaseError = nil; let productID = selectedProductID ?? StoreManager.yearlyProID
        if let product = store.products.first(where: { $0.id == productID }) { do { let success = try await store.purchase(product); if success { trial.startTrial(); onSubscribed(); return } } catch { purchaseError = error.localizedDescription } } else { trial.startTrial(); onSubscribed() }
        purchasing = false
    }
}
