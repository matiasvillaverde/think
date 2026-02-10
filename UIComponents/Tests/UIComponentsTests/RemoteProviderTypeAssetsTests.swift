import Abstractions
import Testing

@testable import UIComponents

@Suite
internal struct RemoteProviderTypeAssetsTests {
    @Test
    func fromRemoteLocationParsesProviderPrefix() {
        #expect(RemoteProviderType.fromRemoteLocation("openai:gpt-4o") == .openAI)
        let openRouterLocation: String = "openrouter:google/gemini-2.0-flash"
        #expect(RemoteProviderType.fromRemoteLocation(openRouterLocation) == .openRouter)
        #expect(RemoteProviderType.fromRemoteLocation("anthropic:claude-3-5-sonnet") == .anthropic)
        #expect(RemoteProviderType.fromRemoteLocation("google:gemini-2.0-flash") == .google)
    }

    @Test
    func fromRemoteLocationIsCaseInsensitive() {
        #expect(RemoteProviderType.fromRemoteLocation("OpenAI:gpt-4o") == .openAI)
        #expect(RemoteProviderType.fromRemoteLocation("OPENROUTER:anthropic/claude") == .openRouter)
    }

    @Test
    func fromRemoteLocationRejectsInvalidLocations() {
        #expect(RemoteProviderType.fromRemoteLocation("") == nil)
        #expect(RemoteProviderType.fromRemoteLocation("no-colon-prefix") == nil)
        #expect(RemoteProviderType.fromRemoteLocation(":missing") == nil)
        #expect(RemoteProviderType.fromRemoteLocation("unknown:model") == nil)
    }

    @Test
    func assetNameMapsToExistingAssetNames() {
        #expect(RemoteProviderType.openAI.assetName == "openai")
        #expect(RemoteProviderType.openRouter.assetName == "openrouter")
        #expect(RemoteProviderType.anthropic.assetName == "anthropic")
        #expect(RemoteProviderType.google.assetName == "gemini")
    }
}
