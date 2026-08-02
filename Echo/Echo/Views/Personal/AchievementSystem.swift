import SwiftUI
struct AchievementSystem {
    static let achievements: [Achievement] = [
        Achievement(id: "first_contact", icon: "person.crop.circle.badge.plus", title: "First Connection", desc: "Import your first contact", category: .gettingStarted, color: Color(hex: "00B4D8"), req: { s in s.totalContacts >= 1 }),
        Achievement(id: "first_reach", icon: "hand.wave", title: "Hello World", desc: "Record your first interaction", category: .gettingStarted, color: Color(hex: "00C9A7"), req: { s in s.totalInteractions >= 1 }),
        Achievement(id: "first_week", icon: "calendar.badge.checkmark", title: "Week One Warrior", desc: "Use Echo for 7 consecutive days", category: .streaks, color: Color(hex: "FF6B35"), req: { s in s.currentStreak >= 7 }),
        Achievement(id: "streak_30", icon: "flame.fill", title: "Relationship Flame", desc: "Maintain a 30-day streak", category: .streaks, color: Color(hex: "FF4E50"), req: { s in s.currentStreak >= 30 }),
        Achievement(id: "streak_100", icon: "flame.fill", title: "Centurion", desc: "100-day streak", category: .streaks, color: Color(hex: "8B0000"), req: { s in s.currentStreak >= 100 }),
        Achievement(id: "reconnect", icon: "arrow.triangle.2.circlepath", title: "Time Traveler", desc: "Reconnect after 90+ days", category: .milestones, color: Color(hex: "9B59B6"), req: { s in s.reconnections >= 1 }),
        Achievement(id: "ten_healthy", icon: "heart.fill", title: "Relationship Guru", desc: "10+ healthy relationships", category: .milestones, color: Color(hex: "E84393"), req: { s in s.healthyCount >= 10 }),
        Achievement(id: "zero_risk", icon: "shield.fill", title: "Safety Net", desc: "Zero at-risk relationships", category: .milestones, color: Color(hex: "00D9A3"), req: { s in s.totalContacts >= 5 && s.atRiskCount == 0 }),
        Achievement(id: "century", icon: "infinity", title: "Century Club", desc: "100 total interactions", category: .milestones, color: Color(hex: "6B4DE6"), req: { s in s.totalInteractions >= 100 }),
        Achievement(id: "all_channels", icon: "rectangle.grid.2x2.fill", title: "Multi-Channel Master", desc: "Use all 4 interaction types", category: .milestones, color: Color(hex: "FFB347"), req: { s in s.channelsUsed >= 4 }),
    ]
}
struct Achievement: Identifiable { let id: String; let icon: String; let title: String; let desc: String; let category: AchievementCategory; let color: Color; let req: (AchievementStats) -> Bool }
enum AchievementCategory: String, CaseIterable, Identifiable { var id: String { rawValue }
    case gettingStarted = "Getting Started"; case streaks = "Streaks"; case milestones = "Milestones"
    var icon: String { switch self { case .gettingStarted: "person.crop.circle.badge.checkmark"; case .streaks: "flame"; case .milestones: "trophy" } }
}
struct AchievementStats {
    let totalContacts: Int; let totalInteractions: Int; let currentStreak: Int; let reconnections: Int; let healthyCount: Int; let atRiskCount: Int; let channelsUsed: Int
    static func compute(from contacts: [EchoContact]) -> AchievementStats {
        let allI = contacts.flatMap { $0.interactions }; let h = contacts.compactMap { AIEngine.healthScore(for: $0) }
        return AchievementStats(totalContacts: contacts.count, totalInteractions: allI.count, currentStreak: StreakManager.shared.calculateStreak(from: allI.map { $0.date }), reconnections: 0, healthyCount: h.filter { $0.level == .thriving || $0.level == .stable }.count, atRiskCount: h.filter { $0.level == .fading || $0.level == .critical }.count, channelsUsed: Set(allI.map { $0.type }).count)
    }
}
struct AchievementsView: View {
    let contacts: [EchoContact]; @State private var stats: AchievementStats?
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            if let s = stats { let unlocked = AchievementSystem.achievements.filter { $0.req(s) }; let prog = Double(unlocked.count) / Double(AchievementSystem.achievements.count)
                VStack(spacing: 12) { ZStack { Circle().stroke(Color.gray.opacity(0.2), lineWidth: 10).frame(width: 100, height: 100); Circle().trim(from: 0, to: prog).stroke(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 10, lineCap: .round)).frame(width: 100, height: 100).rotationEffect(.degrees(-90)); VStack { Text("\(unlocked.count)").font(.system(size: 28, weight: .bold, design: .rounded)); Text("/ \(AchievementSystem.achievements.count)").font(.system(size: 14)).foregroundStyle(.secondary) } }; Text("Achievements").font(.system(size: 18, weight: .bold, design: .rounded)); Text("\(Int(prog * 100))% Complete").font(.system(size: 13)).foregroundStyle(.secondary) }.padding(.top, 20) }
            ForEach(AchievementCategory.allCases) { cat in
                let achs = AchievementSystem.achievements.filter { $0.category == cat }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) { Image(systemName: cat.icon).font(.system(size: 16)); Text(cat.id).font(.system(size: 17, weight: .bold, design: .rounded)) }.padding(.horizontal, 16)
                    ForEach(0..<achs.count) { i in let a = achs[i]; let u = stats.map { a.req($0) } ?? false; AchievementRow(ach: a, unlocked: u) }
                }
            }.padding(.bottom, 10)
        }.padding(.bottom, 32) }.background(EchoTheme.backgroundGradient.ignoresSafeArea()).navigationTitle("Achievements").navigationBarTitleDisplayMode(.inline).onAppear { stats = AchievementStats.compute(from: contacts) }
    }
}
struct AchievementRow: View {
    let ach: Achievement; let unlocked: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack { Circle().fill(unlocked ? ach.color.opacity(0.2) : Color.gray.opacity(0.1)).frame(width: 48, height: 48); Image(systemName: unlocked ? ach.icon : "lock.fill").font(.system(size: 20)).foregroundStyle(unlocked ? ach.color : Color.gray.opacity(0.5)) }
            VStack(alignment: .leading, spacing: 3) { Text(ach.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(unlocked ? .primary : .secondary); Text(ach.desc).font(.system(size: 12)).foregroundStyle(.secondary) }
            Spacer(); if unlocked { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 20)) }
        }.padding(12).background(unlocked ? ach.color.opacity(0.05) : Color.gray.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
    }
}