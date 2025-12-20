import Testing
@testable import AppStoreConnectCLI

@Test("Basic CLI structure exists")
func testCLIStructureExists() async throws {
    // This test ensures the basic CLI structure compiles
    let provider = try MockConfigurationProvider.createTestProvider()
    let config = try await provider.getConfiguration()
    #expect(config.keyID.hasPrefix("TEST"))
}
