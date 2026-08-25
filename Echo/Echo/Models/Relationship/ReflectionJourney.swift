import Foundation
import SwiftData

@Model
final class ReflectionJourney {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var currentWeekIndex: Int
    var preferredWeekday: Int
    var preferredReminderHour: Int
    var preferredReminderMinute: Int
    var completedThemeRawValues: [String]
    var selectedContactIdentifiers: [String]
    var draftIntentValues: [String]?
    var draftContextValues: [String]?
    var activeStepRawValue: String?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        currentWeekIndex: Int = 1,
        preferredWeekday: Int = 1,
        preferredReminderHour: Int = 10,
        preferredReminderMinute: Int = 0,
        completedThemeRawValues: [String] = [],
        selectedContactIdentifiers: [String] = [],
        draftIntentValues: [String] = [],
        draftContextValues: [String] = [],
        activeStepRawValue: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.currentWeekIndex = currentWeekIndex
        self.preferredWeekday = preferredWeekday
        self.preferredReminderHour = preferredReminderHour
        self.preferredReminderMinute = preferredReminderMinute
        self.completedThemeRawValues = completedThemeRawValues
        self.selectedContactIdentifiers = selectedContactIdentifiers
        self.draftIntentValues = draftIntentValues
        self.draftContextValues = draftContextValues
        self.activeStepRawValue = activeStepRawValue
    }

    var currentTheme: ReflectionTheme {
        let themes: [ReflectionTheme] = [.protect, .reconnect, .lighten, .boundaries]
        return themes[min(max(currentWeekIndex - 1, 0), themes.count - 1)]
    }

    var completedThemes: Set<ReflectionTheme> {
        Set(completedThemeRawValues.compactMap(ReflectionTheme.init(rawValue:)))
    }

    var isComplete: Bool { completedAt != nil || completedThemes.count >= 4 }
}
