import Abstractions
import Foundation

/// Remote LLM session that connects to API providers.
///
/// This actor implements the `LLMSession` protocol to enable streaming
/// text generation from remote API providers like OpenRouter, OpenAI,
/// Anthropic, and Google.
///
/// Key behaviors:
/// - `preload()`: Validates API key exists, returns immediate completion
/// - `stream()`: Builds request, streams SSE, parses chunks
/// - `stop()`: Cancels current URLSession task
/// - `unload()`: No-op (no local resources to unload)
actor RemoteSession: LLMSession {
    /// The API key manager for retrieving provider keys
    private let apiKeyManager: APIKeyManaging

    /// The HTTP client for streaming requests
    private let httpClient: HTTPClientProtocol

    /// The retry policy for handling transient failures
    private let retryPolicy: RetryPolicy

    /// Flag to stop generation
    private let stopFlag = StopFlag()

    /// Current model location (set during preload)
    private var currentLocation: String?

    /// Current provider (resolved from location)
    private var currentProvider: RemoteProvider?

    /// Current model identifier (parsed from location)
    private var currentModelId: String?
    /// Current context window size for metrics
    private var currentContextWindowSize: Int?

    /// Creates a new remote session.
    ///
    /// - Parameters:
    ///   - apiKeyManager: Manager for API keys (defaults to shared keychain manager)
    ///   - httpClient: HTTP client for requests (defaults to shared URLSession client)
    ///   - retryPolicy: Retry policy for transient failures (defaults to standard policy)
    init(
        apiKeyManager: APIKeyManaging = APIKeyManager.shared,
        httpClient: HTTPClientProtocol = HTTPClient.shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.apiKeyManager = apiKeyManager
        self.httpClient = httpClient
        self.retryPolicy = retryPolicy
    }

    // MARK: - LLMSession Protocol

    func preload(
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                do {
                    try await self?.doPreload(configuration: configuration)
                    continuation.yield(Progress(totalUnitCount: 1))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func doPreload(configuration: ProviderConfiguration) async throws {
        let location = configuration.modelName

        // Parse provider and model from location
        let (provider, modelId) = try ProviderRegistry.resolve(location)
        let providerType = try ProviderRegistry.parseProviderType(
            String(location.prefix(while: { $0 != ":" }))
        )

        // Validate API key exists
        guard await apiKeyManager.hasKey(for: providerType) else {
            throw RemoteError.noAPIKey(providerType).toLLMError()
        }

        // Store configuration for streaming
        currentLocation = location
        currentProvider = provider
        currentModelId = modelId
        currentContextWindowSize = configuration.compute.contextSize
    }

    func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                do {
                    try await self?.doStream(input: input, continuation: continuation)
                } catch {
                    if let remoteError = error as? RemoteError {
                        continuation.finish(throwing: remoteError.toLLMError())
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    private func doStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async throws {
        guard let provider = currentProvider,
              let modelId = currentModelId,
              let location = currentLocation else {
            throw RemoteError.invalidModelLocation("No model loaded. Call preload first.")
                .toLLMError()
        }

        // Get API key
        let providerType = try ProviderRegistry.parseProviderType(
            String(location.prefix(while: { $0 != ":" }))
        )
        guard let apiKey = try await apiKeyManager.getKey(for: providerType) else {
            throw RemoteError.noAPIKey(providerType).toLLMError()
        }

        // Build request
        let request = try provider.buildRequest(
            input: input,
            apiKey: apiKey,
            model: modelId
        )

        // Reset stop flag
        await stopFlag.reset()

        try await streamRequest(
            request,
            provider: provider,
            continuation: continuation
        )
    }

    private func streamRequest(
        _ request: URLRequest,
        provider: RemoteProvider,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async throws {
        var latestMetrics: ChunkMetrics?
        do {
            for try await data in httpClient.stream(request) {
                if await stopFlag.isStopped {
                    continuation.finish()
                    return
                }

                let isFinished = await processStreamData(
                    data,
                    provider: provider,
                    continuation: continuation,
                    latestMetrics: &latestMetrics
                )
                if isFinished {
                    return
                }
            }
            continuation.finish()
        } catch {
            throw mapStreamingError(error, provider: provider)
        }
    }

    private func processStreamData(
        _ data: Data,
        provider: RemoteProvider,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation,
        latestMetrics: inout ChunkMetrics?
    ) async -> Bool {
        let events = SSEParser.parse(data)

        for event in events {
            if SSEParser.isDone(event.data) {
                continuation.yield(LLMStreamChunk(
                    text: "",
                    event: .finished,
                    metrics: latestMetrics
                ))
                continuation.finish()
                return true
            }

            do {
                let result = try provider.parseStreamChunk(event.data)
                let metrics = result.usage.map(buildMetrics)
                if let metrics {
                    latestMetrics = metrics
                }

                if !result.content.isEmpty {
                    continuation.yield(LLMStreamChunk(
                        text: result.content,
                        event: .text,
                        metrics: metrics
                    ))
                }

                if result.isDone {
                    finishStreaming(
                        continuation: continuation,
                        metrics: metrics ?? latestMetrics
                    )
                    return true
                }
            } catch {
                // Intentionally ignore parsing errors from non-data events.
            }
        }

        return false
    }

    private func mapStreamingError(_ error: Error, provider: RemoteProvider) -> Error {
        if let httpError = error as? HTTPError {
            switch httpError {
            case let .statusCode(statusCode, body):
                let parsed = provider.parseError(body, statusCode: statusCode)
                return RemoteError.providerError(parsed)

            case .timeout, .invalidResponse:
                return RemoteError.networkError(httpError)

            case .cancelled:
                return RemoteError.cancelled
            }
        }

        if error is CancellationError {
            return RemoteError.cancelled
        }

        // Always normalize remote-session failures into an LLMError so call sites
        // (and UI) get consistent, user-friendly error messaging.
        return RemoteError.networkError(error)
    }

    private func finishStreaming(
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation,
        metrics: ChunkMetrics?
    ) {
        continuation.yield(LLMStreamChunk(
            text: "",
            event: .finished,
            metrics: metrics
        ))
        continuation.finish()
    }

    nonisolated func stop() {
        Task {
            await stopFlag.stop()
        }
    }

    func unload() async {
        // No local resources to unload
        currentLocation = nil
        currentProvider = nil
        currentModelId = nil
        currentContextWindowSize = nil
    }
}

// MARK: - Stop Flag

/// Thread-safe stop flag for cancelling generation.
private actor StopFlag {
    private var stopped = false

    var isStopped: Bool {
        stopped
    }

    func stop() {
        stopped = true
    }

    func reset() {
        stopped = false
    }
}

// MARK: - Metrics

extension RemoteSession {
    private func buildMetrics(from usage: ChatCompletionResponse.Usage) -> ChunkMetrics {
        ChunkMetrics(
            usage: UsageMetrics(
                generatedTokens: usage.completionTokens,
                totalTokens: usage.totalTokens,
                promptTokens: usage.promptTokens,
                contextWindowSize: currentContextWindowSize,
                contextTokensUsed: usage.totalTokens
            )
        )
    }
}
