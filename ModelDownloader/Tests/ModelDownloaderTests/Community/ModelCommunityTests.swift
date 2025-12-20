import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelCommunity Tests")
struct ModelCommunityTests {
    @Test("ModelCommunity initialization")
    func testInitialization() {
        let community: ModelCommunity = ModelCommunity(
            id: "test-community",
            displayName: "Test Community",
            supportedBackends: [.mlx, .gguf],
            description: "A test community"
        )

        #expect(community.id == "test-community")
        #expect(community.displayName == "Test Community")
        #expect(community.supportedBackends == [.mlx, .gguf])
        #expect(community.description == "A test community")
    }

    @Test("ModelCommunity without description")
    func testInitializationWithoutDescription() {
        let community: ModelCommunity = ModelCommunity(
            id: "test-community",
            displayName: "Test Community",
            supportedBackends: [.mlx]
        )

        #expect(community.description == nil)
    }

    @Test("Default communities are properly configured")
    func testDefaultCommunities() {
        let defaults: [ModelCommunity] = ModelCommunity.defaultCommunities

        #expect(defaults.count == 4)

        // Check MLX community
        let mlx: ModelCommunity = defaults[0]
        #expect(mlx.id == "mlx-community")
        #expect(mlx.displayName == "MLX Community")
        #expect(mlx.supportedBackends == [.mlx])
        #expect(mlx.description != nil)

        // Check CoreML community
        let coreml: ModelCommunity = defaults[1]
        #expect(coreml.id == "coreml-community")
        #expect(coreml.displayName == "Core ML Community")
        #expect(coreml.supportedBackends == [.coreml])
        #expect(coreml.description != nil)
    }

    @Test("Find community by ID")
    func testFindByID() {
        let mlx: ModelCommunity? = ModelCommunity.find(by: "mlx-community")
        #expect(mlx != nil)
        #expect(mlx?.displayName == "MLX Community")

        let notFound: ModelCommunity? = ModelCommunity.find(by: "non-existent")
        #expect(notFound == nil)
    }

    @Test("ModelCommunity equality")
    func testEquality() {
        let community1: ModelCommunity = ModelCommunity(
            id: "test",
            displayName: "Test",
            supportedBackends: [.mlx]
        )

        let community2: ModelCommunity = ModelCommunity(
            id: "test",
            displayName: "Test",
            supportedBackends: [.mlx]
        )

        let community3: ModelCommunity = ModelCommunity(
            id: "different",
            displayName: "Test",
            supportedBackends: [.mlx]
        )

        #expect(community1 == community2)
        #expect(community1 != community3)
    }

    @Test("ModelCommunity is Hashable")
    func testHashable() {
        let community: ModelCommunity = ModelCommunity(
            id: "test",
            displayName: "Test",
            supportedBackends: [.mlx]
        )

        var set: Set<ModelCommunity> = Set<ModelCommunity>()
        set.insert(community)

        #expect(set.count == 1)
        #expect(set.contains(community))
    }

    @Test("ModelCommunity is Codable")
    func testCodable() throws {
        let original: ModelCommunity = ModelCommunity(
            id: "test",
            displayName: "Test Community",
            supportedBackends: [.mlx, .gguf],
            description: "Test description"
        )

        let encoder: JSONEncoder = JSONEncoder()
        let data: Data = try encoder.encode(original)

        let decoder: JSONDecoder = JSONDecoder()
        let decoded: ModelCommunity = try decoder.decode(ModelCommunity.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.supportedBackends == original.supportedBackends)
        #expect(decoded.description == original.description)
    }
}
