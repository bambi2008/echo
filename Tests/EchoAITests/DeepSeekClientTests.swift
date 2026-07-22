import Foundation
import Testing
@testable import EchoAI

@Suite("DeepSeek request compatibility", .serialized)
struct DeepSeekClientTests {
    @Test("Selected model is sent to the chat completions endpoint")
    func selectedModelIsSent() async throws {
        let recorder = RequestRecorder()
        MockURLProtocol.install { request in
            try recorder.capture(request)
            let body = """
            {
              "model": "deepseek-v4-pro-actual",
              "choices": [{"message": {"content": "done"}}],
              "usage": {
                "prompt_tokens": 12,
                "completion_tokens": 3,
                "total_tokens": 15
              }
            }
            """.data(using: .utf8)!
            return (200, body)
        }
        defer { MockURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = DeepSeekClient(
            baseURL: URL(string: "https://example.test/v1")!,
            session: session,
            apiKeyProvider: { "test-key" }
        )

        let result = try await client.complete(
            messages: [AIMessage(role: .user, text: "hello")],
            model: "deepseek-any-future-model",
            options: AICompletionOptions(temperature: 0.2, maxOutputTokens: 321)
        )

        let snapshot = try #require(recorder.snapshot)
        let json = try #require(JSONSerialization.jsonObject(with: snapshot.body) as? [String: Any])
        #expect(snapshot.path == "/v1/chat/completions")
        #expect(snapshot.authorization == "Bearer test-key")
        #expect(json["model"] as? String == "deepseek-any-future-model")
        #expect(json["max_tokens"] as? Int == 321)
        #expect(result.text == "done")
        #expect(result.model == "deepseek-v4-pro-actual")
        #expect(result.usage?.totalTokens == 15)
    }

    @Test("Provider errors preserve status and message for fallback decisions")
    func providerError() async throws {
        MockURLProtocol.install { _ in
            let body = #"{"error":{"message":"model temporarily unavailable"}}"#.data(using: .utf8)!
            return (503, body)
        }
        defer { MockURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = DeepSeekClient(
            session: URLSession(configuration: configuration),
            apiKeyProvider: { "test-key" }
        )

        await #expect(
            throws: AIServiceError.http(
                statusCode: 503,
                message: "model temporarily unavailable"
            )
        ) {
            try await client.complete(
                messages: [AIMessage(role: .user, text: "hello")],
                model: "candidate-model",
                options: AICompletionOptions(temperature: 0.7, maxOutputTokens: 100)
            )
        }
    }
}

private final class RequestRecorder: @unchecked Sendable {
    struct Snapshot {
        let path: String
        let authorization: String?
        let body: Data
    }

    private let lock = NSLock()
    private var storedSnapshot: Snapshot?

    var snapshot: Snapshot? {
        lock.withLock { storedSnapshot }
    }

    func capture(_ request: URLRequest) throws {
        let body: Data
        if let directBody = request.httpBody {
            body = directBody
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { throw stream.streamError ?? AIServiceError.invalidResponse }
                if count == 0 { break }
                collected.append(buffer, count: count)
            }
            body = collected
        } else {
            throw AIServiceError.invalidResponse
        }

        let snapshot = Snapshot(
            path: request.url?.path ?? "",
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            body: body
        )
        lock.withLock { storedSnapshot = snapshot }
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func install(_ handler: @escaping Handler) {
        lock.withLock { self.handler = handler }
    }

    static func reset() {
        lock.withLock { handler = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try Self.lock.withLock {
                guard let handler = Self.handler else {
                    throw AIServiceError.transport("Mock handler is missing")
                }
                return handler
            }
            let (statusCode, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
