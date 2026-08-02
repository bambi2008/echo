import SwiftUI
import SwiftData
import StoreKit

struct ReachSheetView: View {
    let contact: EchoContact
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var interactionNote = ""
    @State private var showSuccess = false
    @State private var showMilestone = false
    @State private var milestoneReach = 0
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                if showSuccess { successView.transition(.scale.combined(with: .opacity)) } else {
                    ScrollView {
                        VStack(spacing: EchoTheme.spacing24) {
                            headerView.echoAppear()
                            VStack(spacing: EchoTheme.spacing12) {
                                if let phone = contact.phoneNumber, !phone.isEmpty { actionButton(icon: "phone.fill", label: "Call", color: .green, hasAction: true) { call(phone) }.echoAppear(delay: 0.05); actionButton(icon: "message.fill", label: "Message", color: .blue, hasAction: true) { message(phone) }.echoAppear(delay: 0.1) }
                                if let email = contact.emailAddress, !email.isEmpty { actionButton(icon: "envelope.fill", label: "Email", color: .orange, hasAction: true) { sendEmail(email) }.echoAppear(delay: 0.15) }
                                actionButton(icon: "hand.wave.fill", label: "Log a Reach Out", color: EchoTheme.accent, hasAction: false) { logInteraction(.reachedOut) }.echoAppear(delay: 0.2)
                            }.padding(.horizontal, EchoTheme.spacing24)
                            VStack(alignment: .leading, spacing: EchoTheme.spacing8) {
                                Text("What did you talk about?").font(.caption.weight(.medium)).foregroundStyle(EchoTheme.textTertiary)
                                TextField("Add a note…", text: $interactionNote, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4).tint(EchoTheme.accent)
                            }.padding(.horizontal, EchoTheme.spacing24).echoAppear(delay: 0.25)
                        }.padding(.top, EchoTheme.spacing24)
                    }
                }
            }.navigationTitle("Reach Out").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() }.tint(EchoTheme.textSecondary) } }.sheet(isPresented: $showMilestone) { MilestoneSheet(totalReach: milestoneReach, totalContacts: 1) }
        }
    }
    private var headerView: some View {
        VStack(spacing: EchoTheme.spacing8) {
            if let data = contact.thumbnailData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)) }
            else { Circle().fill(EchoTheme.accentSoft).frame(width: 64, height: 64).overlay(Text(contact.givenName.prefix(1).uppercased()).font(.title.weight(.medium)).foregroundStyle(EchoTheme.accent)) }
            Text(contact.fullName).font(.title3.bold()).foregroundStyle(EchoTheme.textPrimary)
            Text(EchoEngine.gapDescription(for: contact)).font(.subheadline).foregroundStyle(EchoEngine.isOverdue(contact) ? EchoTheme.overdue : EchoTheme.textSecondary)
        }.padding(.top, EchoTheme.spacing8)
    }
    private var successView: some View {
        VStack(spacing: EchoTheme.spacing20) {
            Spacer()
            ZStack { Circle().fill(EchoTheme.success.opacity(0.12)).frame(width: 96, height: 96); Circle().stroke(EchoTheme.success.opacity(0.3), lineWidth: 2).frame(width: 96, height: 96); Image(systemName: "checkmark").font(.system(size: 36, weight: .semibold)).foregroundStyle(EchoTheme.success) }.scaleEffect(showSuccess ? 1 : 0.5)
            VStack(spacing: EchoTheme.spacing4) { Text("Nice!").font(.title.bold()).foregroundStyle(EchoTheme.textPrimary); Text("Echo will remind you when it's time to reconnect.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }.padding(.horizontal, 40)
            if StreakManager.currentStreak > 0 { HStack(spacing: EchoTheme.spacing8) { Text(StreakManager.streakEmoji); Text("\(StreakManager.currentStreak) week streak").font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.accent) }.padding(.horizontal, EchoTheme.spacing16).padding(.vertical, EchoTheme.spacing8).background(EchoTheme.accent.opacity(0.08)).clipShape(Capsule()) }
            Spacer()
            Button { dismiss() } label: { Text("Done").font(.headline).frame(maxWidth: .infinity).frame(height: 50) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).padding(.horizontal, EchoTheme.spacing24).padding(.bottom, EchoTheme.spacing24)
        }
    }
    private func actionButton(icon: String, label: String, color: Color, hasAction: Bool, action: @escaping () -> Void) -> some View {
        Button { EchoHaptics.light(); action() } label: {
            HStack(spacing: EchoTheme.spacing12) { Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color).frame(width: 36, height: 36).background(color.opacity(0.15)).clipShape(Circle()); Text(label).font(.body.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Spacer(); if hasAction { Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(EchoTheme.textTertiary) } }.padding(.horizontal, EchoTheme.spacing16).frame(height: 56).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }
    private func call(_ phone: String) { let cleaned = phone.replacingOccurrences(of: " ", with: ""); if let url = URL(string: "tel:\(cleaned)") { UIApplication.shared.open(url) }; logInteraction(.called) }
    private func message(_ phone: String) { let cleaned = phone.replacingOccurrences(of: " ", with: ""); if let url = URL(string: "sms:\(cleaned)") { UIApplication.shared.open(url) }; logInteraction(.messaged) }
    private func sendEmail(_ email: String) { if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }; logInteraction(.emailed) }
    private func logInteraction(_ type: InteractionType) {
        EchoEngine.recordReach(on: contact, type: type, note: interactionNote, context: modelContext); StreakManager.recordReach(); StreakManager.incrementTotalReach(); EchoHaptics.success()
        let total = StreakManager.totalReachCount; if [10, 25, 50, 100, 200].contains(total) { milestoneReach = total; showMilestone = true }
        RatingManager.promptIfNeeded()
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { showSuccess = true }
        if !showMilestone { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() } }
    }
}
