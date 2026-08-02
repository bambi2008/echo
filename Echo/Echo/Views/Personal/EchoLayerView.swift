import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\.EchoContact.lastReachedOut, order: .forward)]) private var allContacts: [EchoContact]
    @Binding var ahaContact: EchoContact?
    @State private var selectedContact: EchoContact?
    @State private var showReachSheet = false
    @State private var showPaywall = false
    @State private var showAhaBanner = true
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreManager
    private var contacts: [EchoContact] { store.isPro ? allContacts : Array(allContacts.prefix(FreeTierLimits.maxEchoLayerContacts)) }
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                ScrollView {
                    if allContacts.isEmpty { emptyState } else {
                        LazyVStack(spacing: EchoTheme.spacing12) {
                            if StreakManager.currentStreak > 0 || StreakManager.totalReachCount > 0 { StreakStrip().echoAppear(delay: 0) }
                            if isMonday { WeeklyReviewCard(contacts: allContacts, onDismiss: {}).echoAppear(delay: 0.05) }
                            if let contact = ahaContact, showAhaBanner { AhaBanner(contact: contact) { withAnimation { showAhaBanner = false } } onReachOut: { selectedContact = contact; showReachSheet = true }.echoAppear(delay: 0.1) }
                            ForEach(Array(contacts.enumerated()), id: \.element.systemIdentifier) { index, contact in
                                EchoCardView(contact: contact) { selectedContact = contact; showReachSheet = true }.echoAppear(delay: Double(index) * 0.04).contextMenu { Button { demote(contact) } label: { Label("Move to Library", systemImage: "tray.and.arrow.down") } }
                            }
                            if !store.isPro && allContacts.count > FreeTierLimits.maxEchoLayerContacts { UpgradeHintCard(visible: FreeTierLimits.maxEchoLayerContacts, total: allContacts.count, onTap: { showPaywall = true }).echoAppear(delay: 0.3) }
                        }.padding(.horizontal, EchoTheme.spacing16).padding(.top, EchoTheme.spacing8)
                    }
                }
            }.navigationTitle("Echo").navigationBarTitleDisplayMode(.large).tint(EchoTheme.accent).sheet(isPresented: $showReachSheet) { if let contact = selectedContact { ReachSheetView(contact: contact) } }.sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        }
    }
    private var isMonday: Bool { Calendar.current.component(.weekday, from: Date()) == 2 }
    private func demote(_ contact: EchoContact) { EchoHaptics.selection(); contact.isInEchoLayer = false; try? modelContext.save() }
    private var emptyState: some View {
        VStack(spacing: EchoTheme.spacing20) {
            Spacer().frame(height: 60)
            ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 100, height: 100); Image(systemName: "person.3.sequence").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(EchoTheme.accent.opacity(0.5)) }
            VStack(spacing: EchoTheme.spacing8) { Text("Your Echo Layer is empty").font(.headline).foregroundStyle(EchoTheme.textPrimary); Text("Import your contacts to see who you should reach out to.").font(.subheadline).foregroundStyle(EchoTheme.textTertiary).multilineTextAlignment(.center) }.padding(.horizontal, 40)
        }.frame(maxWidth: .infinity)
    }
}

private struct StreakStrip: View {
    private var streak: Int { StreakManager.currentStreak }
    private var total: Int { StreakManager.totalReachCount }
    var body: some View {
        HStack(spacing: EchoTheme.spacing12) {
            VStack(spacing: 2) { Text(StreakManager.streakEmoji).font(.title2); Text("\(streak)").font(.caption.weight(.bold)).foregroundStyle(EchoTheme.textPrimary) }.frame(width: 48, height: 48).background(EchoTheme.accent.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) { Text("Weekly Streak").font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.textPrimary); Text("\(total) total reaches").font(.caption).foregroundStyle(EchoTheme.textTertiary) }
            Spacer()
            HStack(spacing: 3) { ForEach(0..<7, id: \.self) { i in Circle().fill(i < min(streak, 7) ? EchoTheme.accent : Color.white.opacity(0.1)).frame(width: 8, height: 8) } }
        }.padding(.horizontal, EchoTheme.spacing16).padding(.vertical, EchoTheme.spacing12).background(LinearGradient(colors: [EchoTheme.accent.opacity(0.08), EchoTheme.bgCard], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous).stroke(EchoTheme.accent.opacity(0.15), lineWidth: 0.5))
    }
}

private struct AhaBanner: View {
    let contact: EchoContact
    let onDismiss: () -> Void
    let onReachOut: () -> Void
    var body: some View {
        HStack(spacing: EchoTheme.spacing12) {
            Image(systemName: "sparkles").font(.system(size: 16, weight: .medium)).foregroundStyle(EchoTheme.accent)
            Text(AhaMomentHelper.ahaMessage(for: contact)).font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textPrimary).lineLimit(2)
            Spacer()
            Button("Reach") { EchoHaptics.light(); onReachOut() }.font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7).background(EchoTheme.accent).foregroundStyle(.white).clipShape(Capsule())
            Button { onDismiss() } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(EchoTheme.textTertiary) }
        }.padding(.horizontal, EchoTheme.spacing16).padding(.vertical, EchoTheme.spacing12).background(EchoTheme.accent.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(EchoTheme.accent.opacity(0.2), lineWidth: 1))
    }
}

private struct UpgradeHintCard: View {
    let visible: Int; let total: Int; let onTap: () -> Void
    var body: some View {
        Button(action: { EchoHaptics.light(); onTap() }) {
            HStack(spacing: EchoTheme.spacing12) { Image(systemName: "lock.fill").font(.system(size: 18)).foregroundStyle(EchoTheme.accent).frame(width: 36, height: 36).background(EchoTheme.accent.opacity(0.1)).clipShape(Circle()); VStack(alignment: .leading, spacing: 2) { Text("\(total - visible) more in Echo Layer").font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Text("Upgrade to Pro for unlimited contacts").font(.caption).foregroundStyle(EchoTheme.textTertiary) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(EchoTheme.textTertiary) }.padding(EchoTheme.spacing16).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous))
        }.buttonStyle(.plain)
    }
}
