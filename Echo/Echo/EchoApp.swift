import SwiftData
import SwiftUI

@main
struct EchoApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            EchoContact.self,
            Interaction.self,
            EchoNote.self,
            Deal.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create Echo data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
