import SwiftUI

struct EchoCardView: View {
    let contact: EchoContact
    let onReachOut: () -> Void
    private var gapText: String { EchoEngine.gapDescription(for: contact) }
    private var isOverdue: Bool { EchoEngine.isOverdue(contact) }
    var body: some View {
        Button(action: { EchoHaptics.light(); onReachOut() }) {
            HStack(spacing: EchoTheme.spacing12) {
                avatarView
                VStack(alignment: .leading, spacing: EchoTheme.spacing4) {
                    HStack(spacing: 6) { Text(contact.fullName).font(.body.weight(.semibold)).foregroundStyle(EchoTheme.textPrimary).lineLimit(1); if isOverdue { overdueBadge } }
                    Text(gapText).font(.caption).foregroundStyle(isOverdue ? EchoTheme.overdue : EchoTheme.textSecondary)
                    if contact.reachCount > 0 { HStack(spacing: 4) { Image(systemName: "arrow.2.squarepath").font(.system(size: 9)); Text("\(contact.reachCount)").font(.caption2) }.foregroundStyle(EchoTheme.textTertiary) }
                }
                Spacer()
                reachButton
            }.padding(EchoTheme.spacing16).background(LinearGradient(colors: isOverdue ? [EchoTheme.overdue.opacity(0.06), EchoTheme.bgSecondary] : [EchoTheme.bgCard, EchoTheme.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous).stroke(isOverdue ? EchoTheme.overdue.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 0.5)).shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
        }.buttonStyle(.plain).contentShape(RoundedRectangle(cornerRadius: EchoTheme.radius16))
    }
    private var avatarView: some View {
        ZStack {
            if let data = contact.thumbnailData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle()) }
            else { Circle().fill(LinearGradient(colors: [EchoTheme.accentSoft, EchoTheme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48).overlay(Text(contact.givenName.prefix(1).uppercased()).font(.headline.weight(.medium)).foregroundStyle(EchoTheme.accent)) }
            Circle().stroke(isOverdue ? EchoTheme.overdue.opacity(0.5) : Color.clear, lineWidth: 2).frame(width: 52, height: 52)
        }
    }
    private var overdueBadge: some View { Text("!").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).frame(width: 16, height: 16).background(EchoTheme.overdue).clipShape(Circle()) }
    private var reachButton: some View { Image(systemName: "hand.wave").font(.system(size: 18, weight: .medium)).foregroundStyle(EchoTheme.accent).frame(width: 44, height: 44).background(EchoTheme.accent.opacity(0.12)).clipShape(Circle()).overlay(Circle().stroke(EchoTheme.accent.opacity(0.2), lineWidth: 1)) }
}
