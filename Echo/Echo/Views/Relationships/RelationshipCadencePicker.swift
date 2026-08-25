import SwiftUI

struct RelationshipCadencePicker: View {
    @Binding var days: Int?
    @State private var customDays = 45

    private let standardDays = [7, 30, 90]

    var body: some View {
        Picker(String(localized: "Rhythm"), selection: choice) {
            Text(String(localized: "No fixed rhythm")).tag(0)
            Text(String(localized: "Every week")).tag(7)
            Text(String(localized: "Every month")).tag(30)
            Text(String(localized: "Every three months")).tag(90)
            Text(String(localized: "Custom…")).tag(-1)
        }
        if choice.wrappedValue == -1 {
            Stepper(
                String(localized: "Every \(customDays) days"),
                value: $customDays,
                in: 1...365
            )
            .onChange(of: customDays) { _, value in days = value }
        }
    }

    private var choice: Binding<Int> {
        Binding(
            get: {
                guard let days else { return 0 }
                return standardDays.contains(days) ? days : -1
            },
            set: { value in
                switch value {
                case 0: days = nil
                case -1: days = customDays
                default: days = value
                }
            }
        )
    }

    init(days: Binding<Int?>) {
        _days = days
        _customDays = State(initialValue: days.wrappedValue.flatMap { [7, 30, 90].contains($0) ? nil : $0 } ?? 45)
    }
}
