import SwiftUI
import SwiftData

@main
struct EchoApp: App {
    @StateObject private var storeManager = StoreManager.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(storeManager)
                .modelContainer(for: [EchoContact.self, Interaction.self, Note.self, Deal.self])
        }
    }
}
