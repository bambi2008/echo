import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    func requestPermission() async -> Bool {
        do { return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) } catch { return false }
    }

    func scheduleSmartReminder(_ reminder: SmartReminder) {
        let content = UNMutableNotificationContent()
        content.title = "Echo AI 提醒"
        content.body = "\(reminder.contact.givenName)：\(reminder.reason)"
        content.subtitle = "建议通过\(reminder.suggestedChannel.label)联系"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        content.userInfo = ["contactId": reminder.contact.systemIdentifier, "channel": reminder.suggestedChannel.rawValue, "priority": reminder.priority.rawValue]
        content.interruptionLevel = reminder.priority == .urgent ? .timeSensitive : .active
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.suggestedTime), repeats: false)
        let request = UNNotificationRequest(identifier: "echo_reminder_\(reminder.contact.systemIdentifier)_\(reminder.suggestedTime.timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAllSmartReminders(for contacts: [EchoContact]) {
        let reminders = AIEngine.generateSmartNotifications(for: contacts)
        for (index, r) in reminders.enumerated() {
            var t = r.suggestedTime
            if index > 0 { t = t.addingTimeInterval(TimeInterval(index * 1800)) }
            let r2 = SmartReminder(contact: r.contact, suggestedTime: t, reason: r.reason, suggestedChannel: r.suggestedChannel, priority: r.priority)
            scheduleSmartReminder(r2)
        }
    }

    func scheduleDailyEchoBriefing(for contacts: [EchoContact]) {
        let content = UNMutableNotificationContent()
        content.title = "☀️ 今日 Echo"
        let urgent = contacts.filter { c in let d = c.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999; return d >= 14 }
        if urgent.isEmpty { content.body = "今天没有紧急联系任务。保持你的关系网络健康 💚" }
        else { let names = urgent.prefix(3).map { $0.givenName }.joined(separator: "、"); content.body = "今天建议联系 \(urgent.count) 个人：\(names)..." }
        content.sound = .default; content.categoryIdentifier = "DAILY_BRIEFING"; content.interruptionLevel = .active
        var dc = DateComponents(); dc.hour = 9; dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "echo_daily_briefing", content: content, trigger: trigger))
    }

    func scheduleWeeklyReport(for contacts: [EchoContact]) {
        let s = AIEngine.generateWeeklySummary(contacts: contacts)
        let content = UNMutableNotificationContent()
        content.title = "📊 Echo 周报"; content.body = "本周联系\(s.totalReachouts)次，\(s.relationshipsAtRisk)段关系需关注。点击查看详情"
        content.sound = .default; content.categoryIdentifier = "WEEKLY_REPORT"; content.interruptionLevel = .active
        var dc = DateComponents(); dc.weekday = 1; dc.hour = 20; dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "echo_weekly_report", content: content, trigger: trigger))
    }

    func scheduleCriticalAlert(for contact: EchoContact) {
        let days = contact.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999
        guard days >= 45 else { return }
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 关系预警"; content.body = "你和 \(contact.givenName) 已经 \(days) 天没有联系了。长期的沉默可能让这段关系难以恢复。"
        content.sound = .default; content.categoryIdentifier = "CRITICAL_ALERT"; content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "echo_critical_\(contact.systemIdentifier)", content: content, trigger: trigger))
    }

    func cancelAll() { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }

    func cancelReminders(for contactId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { ($0.content.userInfo["contactId"] as? String) == contactId }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func pendingCount() async -> Int { await UNUserNotificationCenter.current().pendingNotificationRequests().count }
}

extension SmartReminder {
    init(contact: EchoContact, suggestedTime: Date, reason: String, suggestedChannel: InteractionType, priority: ReminderPriority) {
        self.contact = contact; self.suggestedTime = suggestedTime; self.reason = reason; self.suggestedChannel = suggestedChannel; self.priority = priority
    }
}