import SwiftUI
import SwiftData

@main
struct EchoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .modelContainer(for: [EchoContact.self, Interaction.self, Note.self, Deal.self])
                .task {
                    await NotificationScheduler.shared.requestPermission()
                }
        }
    }
}
