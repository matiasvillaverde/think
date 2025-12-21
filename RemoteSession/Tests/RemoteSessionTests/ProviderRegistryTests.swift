import Testing
@testable import RemoteSession

@Suite("Provider Registry Tests")
struct ProviderRegistryTests {
    @Test("Parse OpenRouter provider from location")
    func parseOpenRouterProvider() throws {
        let (provider, model) = try ProviderRegistry.resolve(
            "openrouter:google/gemini-2.0-flash-exp:free"
        )

        #expect(provider is OpenRouterProvider)
        #expect(model == "google/gemini-2.0-flash-exp:free")
    }

    @Test("Parse OpenAI provider from location")
    func parseOpenAIProvider() throws {
        let (provider, model) = try ProviderRegistry.resolve("openai:gpt-4o-mini")

        #expect(provider is OpenAIProvider)
        #expect(model == "gpt-4o-mini")
    }

    @Test("Parse Anthropic provider from location")
    func parseAnthropicProvider() throws {
        let (provider, model) = try ProviderRegistry.resolve(
            "anthropic:claude-3-haiku-20240307"
        )

        #expect(provider is AnthropicProvider)
        #expect(model == "claude-3-haiku-20240307")
    }

    @Test("Parse Google provider from location")
    func parseGoogleProvider() throws {
        let (provider, model) = try ProviderRegistry.resolve("google:gemini-1.5-flash")

        #expect(provider is GoogleProvider)
        #expect(model == "gemini-1.5-flash")
    }

    @Test("Parse Google provider with gemini prefix")
    func parseGeminiProvider() throws {
        let (provider, model) = try ProviderRegistry.resolve("gemini:gemini-1.5-flash")

        #expect(provider is GoogleProvider)
        #expect(model == "gemini-1.5-flash")
    }

    @Test("Handle unknown provider")
    func handleUnknownProvider() throws {
        #expect(throws: RemoteError.self) {
            _ = try ProviderRegistry.resolve("unknown:model")
        }
    }

    @Test("Handle malformed location - no colon")
    func handleMalformedLocationNoColon() throws {
        #expect(throws: RemoteError.self) {
            _ = try ProviderRegistry.resolve("openai-gpt-4o-mini")
        }
    }

    @Test("Handle malformed location - empty model")
    func handleMalformedLocationEmptyModel() throws {
        #expect(throws: RemoteError.self) {
            _ = try ProviderRegistry.resolve("openai:")
        }
    }

    @Test("Parse provider type correctly")
    func parseProviderType() throws {
        #expect(try ProviderRegistry.parseProviderType("openrouter") == .openRouter)
        #expect(try ProviderRegistry.parseProviderType("openai") == .openAI)
        #expect(try ProviderRegistry.parseProviderType("anthropic") == .anthropic)
        #expect(try ProviderRegistry.parseProviderType("google") == .google)
        #expect(try ProviderRegistry.parseProviderType("gemini") == .google)
    }

    @Test("Create correct provider for type")
    func createProviderForType() {
        #expect(ProviderRegistry.createProvider(for: .openRouter) is OpenRouterProvider)
        #expect(ProviderRegistry.createProvider(for: .openAI) is OpenAIProvider)
        #expect(ProviderRegistry.createProvider(for: .anthropic) is AnthropicProvider)
        #expect(ProviderRegistry.createProvider(for: .google) is GoogleProvider)
    }
}
