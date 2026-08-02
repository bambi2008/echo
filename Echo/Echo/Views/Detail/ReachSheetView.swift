import SwiftUI
import SwiftData
struct ReachSheetView: View {
    let contact: EchoContact
    var onComplete: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var interactionNote = ""; @State private var showSuccess = false; @State private var showMilestone = false; @State private var milestoneReach = 0
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                if showSuccess { successView.transition(.scale.combined(with: .opacity)) } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerView.echoAppear()
                            VStack(spacing: 12) {
                                if let phone = contact.phoneNumber, !phone.isEmpty { actionButton("phone.fill", "Call", .green, true) { call(phone) }.echoAppear(delay: 0.05); actionButton("message.fill", "Message", .blue, true) { message(phone) }.echoAppear(delay: 0.1) }
                                if let email = contact.emailAddress, !email.isEmpty { actionButton("envelope.fill", "Email", .orange, true) { sendEmail(email) }.echoAppear(delay: 0.15) }
                                actionButton("hand.wave.fill", "Log a Reach Out", EchoTheme.accent, false) { logInteraction(.reachedOut) }.echoAppear(delay: 0.2)
                            }.padding(.horizontal, 24)
                            VStack(alignment: .leading, spacing: 8) { Text("What did you talk about?").font(.caption.weight(.medium)).foregroundStyle(EchoTheme.textTertiary); TextField("Add a note…", text: $interactionNote, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4).tint(EchoTheme.accent) }.padding(.horizontal, 24).echoAppear(delay: 0.25)
                        }.padding(.top, 24)
                    }
                }
            }.navigationTitle("Reach Out").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() }.tint(EchoTheme.textSecondary) } }
            .sheet(isPresented: $showMilestone) { MilestoneSheet(totalReach: milestoneReach, totalContacts: 1) }
        }
    }
    private var headerView: some View {
        VStack(spacing: 8) {
            if let d = contact.thumbnailData, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)) } else { Circle().fill(EchoTheme.accentSoft).frame(width: 64, height: 64).overlay(Text(contact.givenName.prefix(1).uppercased()).font(.title.weight(.medium)).foregroundStyle(EchoTheme.accent)) }
            Text(contact.fullName).font(.title3.bold()).foregroundStyle(EchoTheme.textPrimary)
            Text(EchoEngine.gapDescription(for: contact)).font(.subheadline).foregroundStyle(EchoEngine.isOverdue(contact) ? EchoTheme.overdue : EchoTheme.textSecondary)
        }.padding(.top, 8)
    }
    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack { Circle().fill(EchoTheme.success.opacity(0.12)).frame(width: 96, height: 96); Circle().stroke(EchoTheme.success.opacity(0.3), lineWidth: 2).frame(width: 96, height: 96); Image(systemName: "checkmark").font(.system(size: 36, weight: .semibold)).foregroundStyle(EchoTheme.success) }.scaleEffect(showSuccess ? 1 : 0.5)
            VStack(spacing: 4) { Text("Nice!").font(.title.bold()).foregroundStyle(EchoTheme.textPrimary); Text("Echo will remind you when it's time to reconnect.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }.padding(.horizontal, 40)
            if StreakManager.currentStreak > 0 { HStack(spacing: 8) { Text(StreakManager.streakEmoji); Text("\(StreakManager.currentStreak) week streak").font(.subheadline.weight(.semibold)).foregroundStyle(EchoTheme.accent) }.padding(.horizontal, 16).padding(.vertical, 8).background(EchoTheme.accent.opacity(0.08)).clipShape(Capsule()) }
            Spacer()
            Button { dismiss(); onComplete?() } label: { Text("Done").font(.headline).frame(maxWidth: .infinity).frame(height: 50) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).padding(.horizontal, 24).padding(.bottom, 24)
        }
    }
    private func actionButton(_ icon: String, _ label: String, _ color: Color, _ hasAction: Bool, _ action: @escaping () -> Void) -> some View {
        Button { EchoHaptics.light(); action() } label: { HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color).frame(width: 36, height: 36).background(color.opacity(0.15)).clipShape(Circle()); Text(label).font(.body.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Spacer(); if hasAction { Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(EchoTheme.textTertiary) } }.padding(.horizontal, 16).frame(height: 56).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5)) }.buttonStyle(.plain)
    }
    private func call(_ phone: String) { if let u = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") { UIApplication.shared.open(u) }; logInteraction(.called) }
    private func message(_ phone: String) { if let u = URL(string: "sms:\(phone.replacingOccurrences(of: " ", with: ""))") { UIApplication.shared.open(u) }; logInteraction(.messaged) }
    private func sendEmail(_ email: String) { if let u = URL(string: "mailto:\(email)") { UIApplication.shared.open(u) }; logInteraction(.emailed) }
    private func logInteraction(_ type: InteractionType) { EchoEngine.recordReach(on: contact, type: type, note: interactionNote, context: modelContext); StreakManager.recordReach(); StreakManager.incrementTotalReach(); EchoHaptics.success(); let total = StreakManager.totalReachCount; if [10, 25, 50, 100, 200].contains(total) { milestoneReach = total; showMilestone = true }; withAnimation(.spring) { showSuccess = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { RatingManager.promptIfNeeded() } }
}