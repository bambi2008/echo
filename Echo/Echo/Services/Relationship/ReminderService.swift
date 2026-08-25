import Foundation
import UserNotifications

struct EchoReminderRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
    let repeats: Bool
}

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: EchoReminderRequest) async throws
    func cancel(identifiers: [String])
}

struct LocalNotificationScheduler: NotificationScheduling {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ request: EchoReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: request.dateComponents,
            repeats: request.repeats
        )
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        ))
    }

    func cancel(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

struct ReminderService {
    static let weeklyIdentifier = "echo.relationship.weekly"
    static let reviewPrefix = "echo.relationship.review."
    static let actionPrefix = "echo.relationship.action."

    let scheduler: any NotificationScheduling

    init(scheduler: any NotificationScheduling = LocalNotificationScheduler()) {
        self.scheduler = scheduler
    }

    func requestPermission() async throws -> Bool {
        try await scheduler.requestAuthorization()
    }

    func scheduleWeekly(weekday: Int, hour: Int, minute: Int) async throws {
        scheduler.cancel(identifiers: [Self.weeklyIdentifier])
        try await scheduler.schedule(EchoReminderRequest(
            identifier: Self.weeklyIdentifier,
            title: String(localized: "A moment with Echo"),
            body: String(localized: "This week, Echo would like to remember one person with you."),
            dateComponents: DateComponents(hour: hour, minute: minute, weekday: weekday),
            repeats: true
        ))
    }

    func scheduleAction(_ action: RelationshipAction, contactName: String) async throws {
        guard action.status == .planned, let date = action.plannedFor else { return }
        let identifier = Self.actionPrefix + action.id.uuidString
        scheduler.cancel(identifiers: [identifier])
        try await scheduler.schedule(EchoReminderRequest(
            identifier: identifier,
            title: String(localized: "Something you chose for \(contactName)"),
            body: String(localized: "You left one small action in Echo. Is now a good moment?"),
            dateComponents: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        ))
    }

    func scheduleReview(for action: RelationshipAction, date: Date) async throws {
        guard action.status == .completed else { return }
        let identifier = Self.reviewPrefix + action.id.uuidString
        scheduler.cancel(identifiers: [identifier])
        try await scheduler.schedule(EchoReminderRequest(
            identifier: identifier,
            title: String(localized: "A quiet look back"),
            body: String(localized: "After that action, does this relationship feel any different?"),
            dateComponents: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        ))
    }

    func cancelAction(_ action: RelationshipAction) {
        scheduler.cancel(identifiers: [
            Self.actionPrefix + action.id.uuidString,
            Self.reviewPrefix + action.id.uuidString,
        ])
    }

    func cancelWeekly() {
        scheduler.cancel(identifiers: [Self.weeklyIdentifier])
    }
}

@MainActor
struct RelationshipReminderCoordinator {
    static let actionReminderKey = "echo.relationship.actionReminder"
    static let reviewReminderKey = "echo.relationship.reviewReminder"

    let reminders: ReminderService
    let defaults: UserDefaults

    init(
        reminders: ReminderService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.reminders = reminders ?? ReminderService()
        self.defaults = defaults
    }

    func schedulePlannedActionIfEnabled(_ action: RelationshipAction) async {
        guard defaults.bool(forKey: Self.actionReminderKey),
              let contact = action.contact
        else { return }
        try? await reminders.scheduleAction(action, contactName: contact.fullName)
    }

    func completeAction(_ action: RelationshipAction) async {
        reminders.cancelAction(action)
        guard defaults.bool(forKey: Self.reviewReminderKey) else { return }
        let reviewDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        try? await reminders.scheduleReview(for: action, date: reviewDate)
    }

    func cancelAction(_ action: RelationshipAction) {
        reminders.cancelAction(action)
    }
}
