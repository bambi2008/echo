import SwiftUI
struct RelationshipWeatherView: View {
    let contacts: [EchoContact]
    @State private var animateClouds = false; @State private var animateRain = false; @State private var pulseLightning = false
    var body: some View { VStack(spacing: 16) { forecastCard; if !alerts.isEmpty { alertsSection }; contactsWeather } }
    private var forecastCard: some View {
        ZStack {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius: 20)).frame(height: 180)
            if weatherType != .sunny { HStack { Image(systemName: "cloud.fill").font(.system(size: 40)).foregroundStyle(Color.white.opacity(0.6)).offset(x: animateClouds ? 180 : -180, y: -30).animation(.easeInOut(duration: 8).repeatForever(autoreverses: false), value: animateClouds); Spacer() } }
            if weatherType == .stormy || weatherType == .hurricane { ForEach(0..<12) { i in RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.4)).frame(width: 2, height: 10).offset(x: CGFloat(i) * 30 - 160, y: animateRain ? 80 : -40).animation(.easeIn(duration: 0.6).repeatForever(autoreverses: false).delay(Double(i) * 0.1), value: animateRain) } }
            VStack(spacing: 8) {
                HStack { Image(systemName: weatherType.icon).font(.system(size: 44, weight: .ultraLight)).foregroundStyle(.white); VStack(alignment: .leading, spacing: 2) { Text(weatherType.label).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white); Text(weatherType.description).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.8)) }; Spacer() }.padding(.horizontal, 20)
                HStack { Text("\(temperature)°").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.white.opacity(0.9)); Spacer(); Text("\(healthyCount)H  \(warningCount)W  \(criticalCount)C").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.white.opacity(0.9)) }.padding(.horizontal, 20)
            }.padding(.top, 20)
        }.onAppear { animateClouds = true; animateRain = true }
    }
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text("天气预警").font(.system(size: 15, weight: .bold, design: .rounded)) }
            ForEach(0..<alerts.count) { i in let a = alerts[i]; HStack(spacing: 10) { Image(systemName: a.icon).font(.system(size: 16)).foregroundStyle(a.color).frame(width: 32, height: 32).background(a.color.opacity(0.15)).clipShape(Circle()); VStack(alignment: .leading, spacing: 2) { Text(a.contact.givenName).font(.system(size: 14, weight: .semibold)); Text(a.message).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer() }.padding(10).background(a.color.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10)) }
        }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
    private var contactsWeather: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每个人的天气").font(.system(size: 15, weight: .bold, design: .rounded)).padding(.leading, 4)
            ForEach(0..<contacts.count) { i in let c = contacts[i]; let h = AIEngine.healthScore(for: c); let w = personalWeather(level: h.level, gap: c.lastReachedOut ?? Date()); HStack(spacing: 12) { ZStack { Circle().fill(w.color.opacity(0.15)).frame(width: 40, height: 40); Image(systemName: w.icon).font(.system(size: 16)).foregroundStyle(w.color) }; VStack(alignment: .leading, spacing: 2) { Text(c.givenName).font(.system(size: 15, weight: .semibold)); Text(w.label).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer(); Text("\(h.score)°").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(w.color) }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 12)) }
        }
    }
    private var weatherType: WeatherType { let atRisk = contacts.filter { AIEngine.healthScore(for: $0).level == .atRisk || AIEngine.healthScore(for: $0).level == .fading || AIEngine.healthScore(for: $0).level == .critical }.count; let r = contacts.isEmpty ? 0 : Double(atRisk) / Double(contacts.count); if r > 0.5 { return .hurricane }; if r > 0.3 { return .stormy }; if r > 0.15 { return .cloudy }; return .sunny }
    private var skyColors: [Color] { switch weatherType { case .sunny: [Color(hex: "00B4D8"), Color(hex: "0077B6"), Color(hex: "03045E")]; case .cloudy: [Color(hex: "8E9EAB"), Color(hex: "636672")]; case .stormy: [Color(hex: "2D3047"), Color(hex: "1A1B4B")]; case .hurricane: [Color(hex: "1A0E2E"), Color(hex: "2D1B6B")] } }
    private var temperature: Int { contacts.isEmpty ? 50 : contacts.map { AIEngine.healthScore(for: $0).score }.reduce(0, +) / contacts.count }
    private var healthyCount: Int { contacts.filter { AIEngine.healthScore(for: $0).level == .thriving || AIEngine.healthScore(for: $0).level == .stable }.count }
    private var warningCount: Int { contacts.filter { AIEngine.healthScore(for: $0).level == .atRisk || AIEngine.healthScore(for: $0).level == .fading }.count }
    private var criticalCount: Int { contacts.filter { AIEngine.healthScore(for: $0).level == .critical }.count }
    private var alerts: [(contact: EchoContact, icon: String, color: Color, message: String)] {
        contacts.filter { AIEngine.healthScore(for: $0).level == .critical || AIEngine.healthScore(for: $0).level == .fading }.sorted { AIEngine.healthScore(for: $0).score < AIEngine.healthScore(for: $1).score }.prefix(3).map { c in let gap = Int(Date().timeIntervalSince(c.lastReachedOut ?? Date()) / 86400); let msg = gap > 60 ? "\(gap)天未联系 — 飓风警报" : "\(gap)天未联系 — 暴风雨来了"; return (c, gap > 60 ? "tornado" : "cloud.bolt.rain", gap > 60 ? .red : .orange, msg) }
    }
    private func personalWeather(level: RelationshipHealth.HealthLevel, gap: Date) -> (icon: String, label: String, color: Color) {
        let days = Int(Date().timeIntervalSince(gap) / 86400)
        switch level { case .thriving: return ("sun.max.fill", "晴朗", Color(hex: "00D9A3")); case .stable: return ("cloud.sun.fill", "多云转晴", Color(hex: "00B4D8")); case .atRisk: return ("cloud.fill", "多云", Color(hex: "FFB347")); case .fading: return ("cloud.rain.fill", "小雨", Color(hex: "FF8C00")); case .critical: return days > 60 ? ("tornado", "飓风", .red) : ("cloud.bolt.rain.fill", "雷暴", .red) }
    }
}
enum WeatherType { case sunny, cloudy, stormy, hurricane; var icon: String { switch self { case .sunny: "sun.max.fill"; case .cloudy: "cloud.fill"; case .stormy: "cloud.bolt.rain.fill"; case .hurricane: "tornado" } }; var label: String { switch self { case .sunny: "晴朗"; case .cloudy: "多云"; case .stormy: "暴风雨"; case .hurricane: "飓风警报" } }; var description: String { switch self { case .sunny: "你的关系生态很健康"; case .cloudy: "有几段关系需要关注"; case .stormy: "多段关系正在淡化"; case .hurricane: "紧急 — 多段关系濒危" } } }