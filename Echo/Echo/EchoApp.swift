import SwiftData
import SwiftUI
import OSLog

@main
struct EchoApp: App {
    @StateObject private var persistence = EchoPersistenceController()

    var body: some Scene {
        WindowGroup {
            if let container = persistence.container {
                EchoLoadedRoot(container: container)
            } else if persistence.couldNotOpenStore {
                EchoPersistenceRecoveryView(retry: persistence.retry)
            } else {
                ProgressView("Opening Echo…")
            }
        }
    }
}

private struct EchoLoadedRoot: View {
    let container: ModelContainer

    var body: some View {
        ContentView()
            .modelContainer(container)
            .task {
                let context = container.mainContext
                do {
                    _ = try PipelineService().migrateExistingData(in: context)
                } catch {
                    Logger(subsystem: "com.bambi2008.Echo", category: "persistence")
                        .error("Pipeline migration failed: \(error.localizedDescription, privacy: .public)")
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--echo-agentic-demo") {
                    do {
                        try PipelineService().seedAcceptanceScenario(in: context)
                    } catch {
                        Logger(subsystem: "com.bambi2008.Echo", category: "ui-testing")
                            .error("Acceptance scenario seed failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
                #endif
            }
    }
}
