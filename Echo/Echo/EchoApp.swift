import SwiftData
import SwiftUI
import OSLog

@main
struct EchoApp: App {
    @StateObject private var persistence = EchoPersistenceController()
    @StateObject private var kipHandoffRouter = KipHandoffRouter()

    var body: some Scene {
        WindowGroup {
            if let container = persistence.container {
                EchoLoadedRoot(container: container)
                    .environmentObject(kipHandoffRouter)
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
                    clearEchoWorkspaceForBusinessEditionIfNeeded(in: context)
                    _ = try PipelineService().migrateExistingData(in: context)
                    // Remove only the synthetic records shipped by earlier
                    // demos. Real iPhone, VCF, and Gmail imports stay intact.
                    DemoData.removeLegacyDemoContacts(in: context)
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

    /// The business edition starts with an intentionally empty Echo-owned
    /// workspace. This one-time migration removes old Echo records only;
    /// iPhone Contacts, Gmail, and any other source account are untouched.
    private func clearEchoWorkspaceForBusinessEditionIfNeeded(in context: ModelContext) {
        let key = "echo.business.workspace.reset.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let contacts = (try? context.fetch(FetchDescriptor<EchoContact>())) ?? []
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        let hasEchoData = !contacts.isEmpty || !deals.isEmpty
        if hasEchoData {
            let reflections = (try? context.fetch(FetchDescriptor<RelationshipReflection>())) ?? []
            let actions = (try? context.fetch(FetchDescriptor<RelationshipAction>())) ?? []
            let journeys = (try? context.fetch(FetchDescriptor<ReflectionJourney>())) ?? []
            let notes = (try? context.fetch(FetchDescriptor<EchoNote>())) ?? []
            let interactions = (try? context.fetch(FetchDescriptor<Interaction>())) ?? []
            let agentIntelligence = (try? context.fetch(FetchDescriptor<AgentIntelligence>())) ?? []
            let agentActions = (try? context.fetch(FetchDescriptor<AgentAction>())) ?? []
            let evidence = (try? context.fetch(FetchDescriptor<Evidence>())) ?? []
            let pipelines = (try? context.fetch(FetchDescriptor<Pipeline>())) ?? []
            let organizations = (try? context.fetch(FetchDescriptor<Organization>())) ?? []

            agentActions.forEach(context.delete)
            agentIntelligence.forEach(context.delete)
            evidence.forEach(context.delete)
            actions.forEach(context.delete)
            reflections.forEach(context.delete)
            journeys.forEach(context.delete)
            interactions.forEach(context.delete)
            notes.forEach(context.delete)
            deals.forEach(context.delete)
            contacts.forEach(context.delete)
            pipelines.forEach(context.delete)
            organizations.forEach(context.delete)
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.set(false, forKey: "echo.onboarding.v2.complete")
        UserDefaults.standard.removeObject(forKey: "echo.relationship.onboarding.stage")
    }
}
