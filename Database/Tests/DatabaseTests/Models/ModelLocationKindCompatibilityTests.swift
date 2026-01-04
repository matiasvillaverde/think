import Testing
import Foundation
@testable import Database
import Abstractions

@Suite("Model LocationKind Compatibility Tests", .tags(.edge, .regression))
struct ModelLocationKindCompatibilityTests {
    private func makeModel() throws -> Model {
        try Model(
            type: .language,
            backend: .mlx,
            name: "compat-test-model",
            displayName: "Compat Test Model",
            displayDescription: "Compatibility test model",
            skills: ["text generation"],
            parameters: 1_000_000,
            ramNeeded: 100_000,
            size: 200_000,
            locationHuggingface: "organization/model",
            version: 2,
            architecture: .unknown
        )
    }

    @Test("Defaults to huggingFace")
    @MainActor
    func defaultsToHuggingFace() throws {
        let model = try makeModel()
        #expect(model.locationKind == .huggingFace)
    }

    @Test("Updates locationKind to remote")
    @MainActor
    func updatesLocationKindToRemote() throws {
        let model = try makeModel()
        model.locationKind = .remote
        #expect(model.locationKind == .remote)
    }

    @Test("Updates locationKind to localFile")
    @MainActor
    func updatesLocationKindToLocalFile() throws {
        let model = try makeModel()
        model.locationKind = .localFile
        #expect(model.locationKind == .localFile)
    }
}
