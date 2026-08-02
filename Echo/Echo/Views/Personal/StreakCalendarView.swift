import SwiftUI
struct StreakCalendarView: View {
    let interactions: [Interaction]
    private let cal = Calendar.current
    private let rows = 7
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "flame.fill").foregroundStyle(.orange); Text("联系热力图").font(.system(size: 17, weight: .bold, design: .rounded)); Spacer(); Text("过去 49 天").font(.system(size: 12)).foregroundStyle(.secondary) }
            let weeks = generateWeeks()
            VStack(spacing: 4) { ForEach(0..<weeks.count) { w in HStack(spacing: 4) { ForEach(0..<7) { d in cellView(weeks[w][d]) } } } }
            HStack(spacing: 6) { Text("少").font(.system(size: 11)).foregroundStyle(.secondary); ForEach(0..<5) { i in RoundedRectangle(cornerRadius: 2).fill(intColor(lvl: i)).frame(width: 12, height: 12) }; Text("多").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); if let s = currentStreak() { HStack(spacing: 4) { Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(.orange); Text("\(s) 天连续").font(.system(size: 13, weight: .semibold, design: .rounded)) } } }
        }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
    struct DayCell { let date: Date; let count: Int; let isToday: Bool }
    private func generateWeeks() -> [[DayCell]] {
        var weeks: [[DayCell]] = []; let today = cal.startOfDay(for: Date()); let wd = cal.component(.weekday, from: today); let start = cal.date(byAdding: .day, value: -(wd - 1 + (rows - 1) * 7), to: today)!
        var dc: [Date: Int] = [:]; for i in interactions { let d = cal.startOfDay(for: i.date); dc[d, default: 0] += 1 }
        for w in 0..<rows { var cells: [DayCell] = []; for d in 0..<7 { let dt = cal.date(byAdding: .day, value: w * 7 + d, to: start)!; cells.append(DayCell(date: dt, count: dc[cal.startOfDay(for: dt)] ?? 0, isToday: cal.isDateInToday(dt))) }; weeks.append(cells) }; return weeks
    }
    private func cellView(_ c: DayCell) -> some View { RoundedRectangle(cornerRadius: 3).fill(intColor(lvl: intLvl(c.count))).frame(width: 28, height: 28).overlay { if c.isToday { RoundedRectangle(cornerRadius: 3).stroke(Color.white, lineWidth: 2) }; if c.count > 0 { Text("\(c.count)").font(.system(size: 9, weight: .bold)).foregroundStyle(c.count > 2 ? .white : .primary) } } }
    private func intLvl(_ n: Int) -> Int { switch n { case 0: 0; case 1: 2; case 2: 3; case 3...4: 4; default: 5 } }
    private func intColor(lvl: Int) -> Color { switch lvl { case 0: Color.gray.opacity(0.12); case 1: Color(hex: "1A1B4B").opacity(0.3); case 2: Color(hex: "6B4DE6").opacity(0.5); case 3: Color(hex: "6B4DE6").opacity(0.7); case 4: Color(hex: "6B4DE6"); default: Color(hex: "00F5FF") } }
    private func currentStreak() -> Int? { let sorted = interactions.map { cal.startOfDay(for: $0.date) }.sorted(by: >); guard !sorted.isEmpty else { return nil }; var s = 0; var check = cal.startOfDay(for: Date()); while sorted.contains(check) { s += 1; check = cal.date(byAdding: .day, value: -1, to: check)! }; return s > 0 ? s : nil }
}