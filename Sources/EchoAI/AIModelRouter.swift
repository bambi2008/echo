import Foundation

public protocol AIModelConfigurationSource: Sendable {
    func loadConfiguration() async throws -> AIModelConfiguration
}

public struct URLModelConfigurationSource: AIModelConfigurationSource {
    private let url: URL
    private let session: URLSession

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    public func loadConfiguration() async throws -> AIModelConfiguration {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AIServiceError.invalidConfiguration("Remote model configuration request failed")
        }
        return try AIModelRouter.decoder.decode(AIModelConfiguration.self, from: data)
    }
}

/// Thread-safe model routing with the following precedence:
/// per-request override > persisted task policy > packaged defaults.
public actor AIModelRouter {
    public static let storageKey = "echo.ai.model.configuration.v1"
    public static let previousStorageKey = "echo.ai.model.configuration.previous.v1"

    private var configuration: AIModelConfiguration
    private let defaults: UserDefaults?

    public init(
        defaults: UserDefaults? = .standard,
        packagedConfiguration: AIModelConfiguration = .deepSeekV4
    ) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.storageKey),
           let saved = try? Self.decoder.decode(AIModelConfiguration.self, from: data)
        {
            self.configuration = Self.migrateRetiredAliases(
                in: saved,
                using: packagedConfiguration
            )
        } else {
            self.configuration = packagedConfiguration
        }
    }

    public func policy(for task: AITask) throws -> AIModelPolicy {
        guard let policy = configuration.policies[task], !policy.candidates.isEmpty else {
            throw AIServiceError.missingModelPolicy(task)
        }
        return policy
    }

    public func currentConfiguration() -> AIModelConfiguration {
        configuration
    }

    /// Switch a task to any model ID. No catalog or app update is required.
    public func setModel(
        _ model: AIModelID,
        for task: AITask,
        fallbacks: [AIModelID] = []
    ) throws {
        guard !model.rawValue.isEmpty else {
            throw AIServiceError.invalidConfiguration("Model ID cannot be empty")
        }
        let old = configuration.policies[task]
        configuration.policies[task] = AIModelPolicy(
            primary: model,
            fallbacks: fallbacks,
            temperature: old?.temperature ?? 0.7,
            maxOutputTokens: old?.maxOutputTokens ?? 800
        )
        configuration.updatedAt = .now
        try persist()
    }

    public func setPolicy(_ policy: AIModelPolicy, for task: AITask) throws {
        guard !policy.candidates.isEmpty else {
            throw AIServiceError.invalidConfiguration("A model policy needs at least one model")
        }
        configuration.policies[task] = policy
        configuration.updatedAt = .now
        try persist()
    }

    public func replaceConfiguration(_ newConfiguration: AIModelConfiguration) throws {
        try Self.validate(newConfiguration)
        try savePreviousConfiguration()
        configuration = newConfiguration
        try persist()
    }

    public func canRollback() -> Bool {
        defaults?.data(forKey: Self.previousStorageKey) != nil
    }

    /// Restores the configuration that was active before the latest complete
    /// replacement or remote refresh.
    public func rollbackToPreviousConfiguration() throws {
        guard let defaults,
              let data = defaults.data(forKey: Self.previousStorageKey),
              let previous = try? Self.decoder.decode(AIModelConfiguration.self, from: data)
        else {
            throw AIServiceError.noPreviousConfiguration
        }
        try Self.validate(previous)
        let current = try Self.encoder.encode(configuration)
        configuration = previous
        defaults.set(current, forKey: Self.previousStorageKey)
        try persist()
    }

    /// Pulls a remotely hosted JSON configuration and atomically activates it.
    /// A failed refresh leaves the last working configuration untouched.
    public func refresh(from source: any AIModelConfigurationSource) async throws {
        let candidate = try await source.loadConfiguration()
        try replaceConfiguration(candidate)
    }

    public func exportConfiguration() throws -> Data {
        try Self.encoder.encode(configuration)
    }

    public static func validate(_ configuration: AIModelConfiguration) throws {
        guard configuration.schemaVersion == 1 else {
            throw AIServiceError.invalidConfiguration("Unsupported schema version: \(configuration.schemaVersion)")
        }
        for task in AITask.allCases {
            guard let policy = configuration.policies[task], !policy.candidates.isEmpty else {
                throw AIServiceError.missingModelPolicy(task)
            }
            guard 0...2 ~= policy.temperature else {
                throw AIServiceError.invalidConfiguration("Temperature for \(task.rawValue) must be between 0 and 2")
            }
            guard policy.maxOutputTokens > 0 else {
                throw AIServiceError.invalidConfiguration("maxOutputTokens for \(task.rawValue) must be positive")
            }
        }
    }

    /// Migrates persisted aliases retired by DeepSeek without overwriting any
    /// newer custom model ID. Task defaults decide whether Flash or Pro is the
    /// appropriate replacement.
    public static func migrateRetiredAliases(
        in configuration: AIModelConfiguration,
        using defaults: AIModelConfiguration = .deepSeekV4
    ) -> AIModelConfiguration {
        let retired: Set<String> = [
            "deepseek-chat",
            "deepseek-reasoner",
            "deepseek-vision",
        ]
        var migrated = configuration
        var changed = false

        for task in AITask.allCases {
            guard let replacement = defaults.policies[task] else { continue }
            guard var policy = migrated.policies[task] else {
                migrated.policies[task] = replacement
                changed = true
                continue
            }

            if retired.contains(policy.primary.rawValue) {
                policy.primary = replacement.primary
                changed = true
            }

            policy.fallbacks = policy.fallbacks.enumerated().map { index, model in
                guard retired.contains(model.rawValue) else { return model }
                changed = true
                if replacement.fallbacks.indices.contains(index) {
                    return replacement.fallbacks[index]
                }
                return replacement.primary
            }
            migrated.policies[task] = policy
        }

        if changed { migrated.updatedAt = .now }
        return migrated
    }

    private func persist() throws {
        guard let defaults else { return }
        defaults.set(try Self.encoder.encode(configuration), forKey: Self.storageKey)
    }

    private func savePreviousConfiguration() throws {
        guard let defaults else { return }
        defaults.set(
            try Self.encoder.encode(configuration),
            forKey: Self.previousStorageKey
        )
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
