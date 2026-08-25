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
            RelationshipReflection.self,
            RelationshipAction.self,
            ReflectionJourney.self,
        ])
        do {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--echo-ui-testing") {
                let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                let url = base.appendingPathComponent("EchoUITests.store")
                if arguments.contains("--echo-ui-reset") {
                    for path in [url.path, url.path + "-shm", url.path + "-wal"] {
                        try? FileManager.default.removeItem(atPath: path)
                    }
                }
                let configuration = ModelConfiguration("EchoUITests", schema: schema, url: url, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: configuration)
            }
            #endif
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
