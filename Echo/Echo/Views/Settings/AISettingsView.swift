import SwiftUI

struct AISettingsView: View {
    @AppStorage("ai_health_scoring") private var healthScoringEnabled = true
    @AppStorage("ai_sentiment_analysis") private var sentimentEnabled = true
    @AppStorage("ai_smart_reminders") private var smartRemindersEnabled = true
    @AppStorage("ai_opening_lines") private var openingLinesEnabled = true
    @AppStorage("ai_insights") private var insightsEnabled = true
    @AppStorage("ai_daily_briefing") private var dailyBriefingEnabled = true
    @AppStorage("ai_weekly_report") private var weeklyReportEnabled = true
    @AppStorage("ai_critical_alerts") private var criticalAlertsEnabled = true
    @AppStorage("ai_critical_threshold") private var criticalThreshold = 45
    @AppStorage("ai_reminder_time") private var reminderHour = 10

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $healthScoringEnabled) { labelRow("关系健康评分", icon: "heart.text.square", color: .pink) }
                Toggle(isOn: $sentimentEnabled) { labelRow("情感分析", icon: "waveform.badge.checkmark", color: .purple) }
                Toggle(isOn: $insightsEnabled) { labelRow("AI 洞察生成", icon: "brain.head.profile", color: .blue) }
                Toggle(isOn: $openingLinesEnabled) { labelRow("开场白生成", icon: "text.bubble", color: .teal) }
            } header: { Text("AI 功能") } footer: { Text("所有 AI 分析 100% 在设备端完成，数据不会上传到云端。") }

            Section {
                Toggle(isOn: $smartRemindersEnabled) { labelRow("智能提醒", icon: "bell.badge", color: .orange) }
                Toggle(isOn: $dailyBriefingEnabled) { labelRow("每日 Echo 简报", icon: "sun.max", color: .yellow) }
                Toggle(isOn: $weeklyReportEnabled) { labelRow("AI 周报推送", icon: "chart.bar.doc.horizontal", color: .blue) }
                Toggle(isOn: $criticalAlertsEnabled) { labelRow("关系危机预警", icon: "exclamationmark.triangle", color: .red) }
            } header: { Text("AI 通知") } footer: { Text("智能提醒会在你通常联系每个人的时间段推送。") }

            Section {
                VStack(alignment: .leading) {
                    HStack { Text("危机预警阈值"); Spacer(); Text("\(criticalThreshold) 天").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(EchoTheme.accentColor) }
                    Slider(value: Binding(get: { Double(criticalThreshold) }, set: { criticalThreshold = Int($0) }), in: 14...90, step: 1).tint(EchoTheme.accentColor)
                    Text("超过此天数未联系将触发预警").font(.caption).foregroundStyle(.secondary)
                }
                Picker("提醒时间", selection: Binding(get: { reminderHour }, set: { reminderHour = $0 })) { ForEach(7..<22) { h in Text("\(h):00").tag(h) } }
            } header: { Text("高级") }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 28)).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("隐私优先").font(.system(size: 15, weight: .semibold))
                        Text("所有 AI 功能使用 Apple Natural Language 框架在设备端运行。你的关系数据永远不会离开你的手机。").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 4)
            } header: { Text("隐私") }
        }
        .navigationTitle("Echo AI 设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labelRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color).frame(width: 28); Text(title).font(.system(size: 15)) }
    }
}