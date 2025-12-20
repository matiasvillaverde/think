import Testing
@testable import Abstractions

@Suite("Chunking Configuration")
struct ChunkingConfigurationTests {
    @Test("ChunkingConfiguration clamps invalid values")
    func testClampsInvalidValues() {
        let config = ChunkingConfiguration(maxTokens: 0, overlap: -3)

        #expect(config.maxTokens == 1)
        #expect(config.overlap == 0)
    }

    @Test("ChunkingConfiguration clamps overlap to maxTokens - 1")
    func testClampsOverlapToMaxTokens() {
        let config = ChunkingConfiguration(maxTokens: 4, overlap: 10)

        #expect(config.maxTokens == 4)
        #expect(config.overlap == 3)
    }

    @Test("ChunkingConfiguration provides expected defaults")
    func testDefaults() {
        #expect(ChunkingConfiguration.disabled.maxTokens == Int.max)
        #expect(ChunkingConfiguration.disabled.overlap == 0)

        #expect(ChunkingConfiguration.fileDefault.maxTokens == 64)
        #expect(ChunkingConfiguration.fileDefault.overlap == 8)
    }

    @Test("Configuration defaults to disabled chunking")
    func testConfigurationDefaultsToDisabledChunking() {
        let config: Configuration = Configuration()

        #expect(config.chunking == .disabled)
    }
}
