# CLAUDE.md

This file provides guidance to Claude Code when working with the RemoteSession module.

## Module Overview

RemoteSession provides integration with remote LLM providers (OpenRouter, OpenAI, Anthropic, Google Gemini) through a unified interface. It implements the `LLMSession` protocol from Abstractions, enabling seamless switching between local and remote model execution.

## Architecture

### Core Components

```
RemoteSession (Actor) → LLMSession Protocol
    ├── HTTPClient (streaming URLSession)
    ├── SSEParser (Server-Sent Events)
    ├── RetryPolicy (exponential backoff)
    ├── Providers/
    │   ├── OpenRouterProvider
    │   ├── OpenAIProvider
    │   ├── AnthropicProvider
    │   └── GoogleProvider
    └── Keychain/
        ├── KeychainStorage
        └── APIKeyManager
```

### Key Design Patterns

1. **Actor-based concurrency**: Main `RemoteSession` is an actor for thread safety
2. **Protocol-based providers**: Each API provider implements `RemoteProvider`
3. **SSE streaming**: Efficient Server-Sent Events parsing for real-time responses
4. **Retry with backoff**: Automatic retry for rate limits (429) with exponential backoff
5. **Factory pattern**: Clean instantiation via `RemoteSessionFactory`

## Development Commands

```bash
# Module-specific commands
make build              # Build module
make test               # Run unit tests
make test-integration   # Run integration tests (requires API keys)
make lint               # Check SwiftLint
make quality            # lint + build + test
```

## Testing Strategy

### Unit Tests
- Mock HTTP client for deterministic testing
- Test SSE parsing with various edge cases
- Test retry policy calculations
- Test provider request building

### Integration Tests
Integration tests require API keys and are skipped by default:
```bash
# Set API key and run integration tests
export OPENROUTER_API_KEY="sk-..."
make test-integration
```

## Provider Model Locations

Model location strings follow this format:
```
provider:model-identifier

Examples:
- openrouter:google/gemini-2.0-flash-exp:free
- openai:gpt-4o-mini
- anthropic:claude-3-haiku-20240307
- google:gemini-1.5-flash
```

## API Key Storage

API keys are stored securely in the macOS Keychain:
- Service: `com.thinkfreely.remotesession`
- Keys are isolated per provider
- Use `APIKeyManager` for all key operations

## Error Handling

The module maps HTTP errors to `LLMError`:
- 401 → `.authenticationFailed`
- 429 → `.rateLimitExceeded(retryAfter:)`
- 404 → `.modelNotFound`
- 500+ → `.providerError`

## Integration with Think

### Protocol Compliance
Implements `LLMSession` from Abstractions module:
```swift
public protocol LLMSession: Actor {
    func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error>
    nonisolated func stop()
    func preload(configuration: ProviderConfiguration) -> AsyncThrowingStream<Progress, Error>
    func unload() async
}
```

### Usage by AgentOrchestrator
```swift
// Created via factory
let session = RemoteSessionFactory.create()

// Used for remote model inference
// preload validates API key exists (no model to load)
for try await _ in await session.preload(configuration: config) { }

// Stream generation
for try await chunk in await session.stream(input) {
    print(chunk.text)
}
```

## Common Development Tasks

### Adding New Provider

1. Create provider file in `Sources/RemoteSession/Providers/NewProvider.swift`
2. Implement `RemoteProvider` protocol
3. Register in `ProviderRegistry`
4. Add `RemoteProviderType` case
5. Add unit tests
6. Add integration test (optional, requires API key)

### Debugging Network Issues

```swift
// Enable URLSession logging
URLSession.shared.configuration.httpAdditionalHeaders = [
    "X-Debug": "true"
]

// Check SSE parsing
SSEParser.parse(data) // Returns [SSEEvent]
```

## Important Notes

1. **No local resources**: Remote sessions don't load models locally
2. **API keys required**: Must configure API key before streaming
3. **Rate limits**: OpenRouter free tier has rate limits
4. **Token counting**: Metrics from provider may differ from local models
5. **Network dependency**: Requires internet connection

## Dependencies

- `Abstractions`: Protocol definitions and types
- Foundation: URLSession for HTTP streaming
- Security: Keychain for secure key storage
