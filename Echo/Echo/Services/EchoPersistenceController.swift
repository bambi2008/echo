import Combine
import OSLog
import SwiftData
import SwiftUI

@MainActor
final class EchoPersistenceController: ObservableObject {
    typealias Loader = @MainActor () throws -> ModelContainer

    @Published private(set) var container: ModelContainer?
    @Published private(set) var couldNotOpenStore = false
    private let loader: Loader

    init(loader: Loader? = nil) {
        self.loader = loader ?? Self.makeDefaultContainer
        openStore()
    }

    func retry() {
        openStore()
    }

    private func openStore() {
        do {
            container = try loader()
            couldNotOpenStore = false
        } catch {
            container = nil
            couldNotOpenStore = true
            Logger(subsystem: "com.bambi2008.Echo", category: "persistence")
                .fault("Echo data store could not be opened: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func makeDefaultContainer() throws -> ModelContainer {
        let schema = Schema([
            EchoContact.self,
            Interaction.self,
            EchoNote.self,
            Deal.self,
            RelationshipReflection.self,
            RelationshipAction.self,
            ReflectionJourney.self,
            Pipeline.self,
            Organization.self,
            AgentIntelligence.self,
            AgentAction.self,
            Evidence.self,
        ])

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--echo-force-store-failure") {
            throw EchoPersistenceTestError.forcedFailure
        }
        if arguments.contains("--echo-ui-testing") {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
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
    }
}

#if DEBUG
private enum EchoPersistenceTestError: Error {
    case forcedFailure
}
#endif

struct EchoPersistenceRecoveryView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Echo could not open your data")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("persistence.title")
            Text("Your existing data has not been deleted or replaced. Close Echo and try again, or tap below after restarting your device.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("persistence.message")
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("persistence.retry")
            Text("If this continues, keep the app installed so the data can be recovered with support.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .accessibilityIdentifier("persistence.recovery")
    }
}
