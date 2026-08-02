import SwiftUI
import SwiftData

struct WeeklyReviewCard: View {
    let contacts: [EchoContact]
    let onDismiss: () -> Void
    private var weekStart: Date { Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date() }
    private var interactionsThisWeek: [Interaction] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return contacts.flatMap { $0.interactions }.filter { $0.date >= weekAgo }.sorted { $0.date > $1.date }
    }
    private var uniquePeopleCount: Int { Set(interactionsThisWeek.compactMap { $0.contact?.systemIdentifier }).count }
    private var mostResponsive: String? {
        let counts = Dictionary(grouping: interactionsThisWeek.compactMap { $0.contact }, by: { $0.systemIdentifier })
        return counts.max { $0.value.count < $1.value.count }?.value.first?.fullName
    }
    private var longestGapClosed: String? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return contacts.filter { $0.lastReachedOut != nil && $0.lastReachedOut! >= weekAgo }.max { a, b in
            let aGap = a.interactions.first { $0.date >= weekAgo }.map { Calendar.current.dateComponents([.day], from: a.lastReachedOut ?? Date(), to: $0.date).day ?? 0 } ?? 0
            let bGap = b.interactions.first { $0.date >= weekAgo }.map { Calendar.current.dateComponents([.day], from: b.lastReachedOut ?? Date(), to: $0.date).day ?? 0 } ?? 0
            return aGap < bGap
        }?.fullName
    }
    var body: some View {
        VStack(alignment: .leading, spacing: EchoTheme.spacing12) {
            HStack {
                HStack(spacing: EchoTheme.spacing8) { Image(systemName: "chart.bar.fill").font(.system(size: 14)).foregroundStyle(EchoTheme.accent).frame(width: 28, height: 28).background(EchoTheme.accent.opacity(0.1)).clipShape(Circle()); Text("Your Week in Echo").font(.headline).foregroundStyle(EchoTheme.textPrimary) }
                Spacer()
                Button { onDismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(EchoTheme.textTertiary) }
            }
            if interactionsThisWeek.isEmpty { Text("You haven't reached out this week yet.\nTap someone below to get started!").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
            else {
                VStack(alignment: .leading, spacing: EchoTheme.spacing8) {
                    statRow(icon: "person.2.fill", label: "Connected with", value: "\(uniquePeopleCount) people")
                    statRow(icon: "arrow.2.squarepath", label: "Interactions", value: "\(interactionsThisWeek.count)")
                    if let name = mostResponsive { statRow(icon: "flame.fill", label: "Most active", value: name) }
                    if let name = longestGapClosed { statRow(icon: "clock.arrow.2.circlepath", label: "Longest gap closed", value: name) }
                }
            }
        }.padding(EchoTheme.spacing16).background(LinearGradient(colors: [EchoTheme.accent.opacity(0.06), EchoTheme.bgCard], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius16, style: .continuous).stroke(EchoTheme.accent.opacity(0.12), lineWidth: 0.5))
    }
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: EchoTheme.spacing8) { Image(systemName: icon).font(.system(size: 11)).foregroundStyle(EchoTheme.accent.opacity(0.7)).frame(width: 18); Text(label).font(.caption).foregroundStyle(EchoTheme.textSecondary); Spacer(); Text(value).font(.caption.weight(.semibold)).foregroundStyle(EchoTheme.textPrimary).lineLimit(1) }
    }
}
