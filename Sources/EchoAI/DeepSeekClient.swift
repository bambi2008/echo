import Foundation

public enum AIMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public enum AIMessageContent: Sendable, Equatable {
    case text(String)
    case parts([AIContentPart])
}

public enum AIContentPart: Sendable, Equatable {
    case text(String)
    case imageURL(String)
}

public struct AIMessage: Sendable, Equatable {
    public let role: AIMessageRole
    public let content: AIMessageContent

    public init(role: AIMessageRole, text: String) {
        self.role = role
        self.content = .text(text)
    }

    public init(role: AIMessageRole, parts: [AIContentPart]) {
        self.role = role
        self.content = .parts(parts)
    }
}

public struct AICompletionOptions: Sendable, Equatable {
    public var temperature: Double
    public var maxOutputTokens: Int
    public var thinkingEnabled: Bool

    public init(
        temperature: Double,
        maxOutputTokens: Int,
        thinkingEnabled: Bool = false
    ) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.thinkingEnabled = thinkingEnabled
    }
}

public protocol AIProviderClient: Sendable {
    func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult
}

public struct DeepSeekClient: AIProviderClient {
    public typealias APIKeyProvider = @Sendable () throws -> String

    private let baseURL: URL
    private let session: URLSession
    private let apiKeyProvider: APIKeyProvider

    public init(
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        session: URLSession = .shared,
        apiKeyProvider: @escaping APIKeyProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    public init(
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        session: URLSession = .shared,
        apiKeyStore: any AIAPIKeyStore
    ) {
        self.init(baseURL: baseURL, session: session) {
            try apiKeyStore.readAPIKey() ?? ""
        }
    }

    public func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult {
        let apiKey = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIServiceError.noAPIKey }
        guard !model.rawValue.isEmpty else {
            throw AIServiceError.invalidConfiguration("Model ID cannot be empty")
        }

        let endpoint = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                model: model.rawValue,
                messages: messages.map(WireMessage.init),
                temperature: options.temperature,
                maxTokens: options.maxOutputTokens,
                thinking: Thinking(
                    type: options.thinkingEnabled ? "enabled" : "disabled"
                )
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let errorBody = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AIServiceError.http(
                statusCode: http.statusCode,
                message: errorBody?.error.message ?? String(data: data, encoding: .utf8) ?? "Unknown API error"
            )
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw AIServiceError.decoding(error.localizedDescription)
        }
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        return AIResult(
            text: text,
            model: AIModelID(rawValue: decoded.model ?? model.rawValue),
            usage: decoded.usage.map {
                AIUsage(
                    promptTokens: $0.promptTokens,
                    completionTokens: $0.completionTokens,
                    totalTokens: $0.totalTokens
                )
            }
        )
    }
}

private extension DeepSeekClient {
    struct RequestBody: Encodable {
        let model: String
        let messages: [WireMessage]
        let temperature: Double
        let maxTokens: Int
        let thinking: Thinking

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, thinking
            case maxTokens = "max_tokens"
        }
    }

    struct Thinking: Encodable {
        let type: String
    }

    struct WireMessage: Encodable {
        let role: AIMessageRole
        let content: WireContent

        init(_ message: AIMessage) {
            role = message.role
            switch message.content {
            case .text(let text):
                content = .text(text)
            case .parts(let parts):
                content = .parts(parts.map(WirePart.init))
            }
        }
    }

    enum WireContent: Encodable {
        case text(String)
        case parts([WirePart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text): try container.encode(text)
            case .parts(let parts): try container.encode(parts)
            }
        }
    }

    struct WirePart: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        init(_ part: AIContentPart) {
            switch part {
            case .text(let text):
                self.type = "text"
                self.text = text
                self.imageURL = nil
            case .imageURL(let url):
                self.type = "image_url"
                self.text = nil
                self.imageURL = ImageURL(url: url)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    struct ImageURL: Encodable { let url: String }

    struct ResponseBody: Decodable {
        let model: String?
        let choices: [Choice]
        let usage: Usage?
    }

    struct Choice: Decodable { let message: ResponseMessage }
    struct ResponseMessage: Decodable { let content: String? }
    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct ErrorEnvelope: Decodable { let error: APIError }
    struct APIError: Decodable { let message: String }
}
