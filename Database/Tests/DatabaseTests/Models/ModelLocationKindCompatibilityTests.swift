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

    @Test("Defaults to huggingFace when raw value is missing")
    @MainActor
    func defaultsWhenRawMissing() throws {
        let model = try makeModel()
        model.locationKindRaw = nil

        #expect(model.locationKind == .huggingFace)
    }

    @Test("Defaults to huggingFace when raw value is unknown")
    @MainActor
    func defaultsWhenRawUnknown() throws {
        let model = try makeModel()
        model.locationKindRaw = "legacy"

        #expect(model.locationKind == .huggingFace)
    }

    @Test("Maps raw value to enum")
    @MainActor
    func mapsRawValue() throws {
        let model = try makeModel()
        model.locationKindRaw = ModelLocationKind.remote.rawValue

        #expect(model.locationKind == .remote)
    }

    @Test("Setter updates raw storage")
    @MainActor
    func setterUpdatesRawStorage() throws {
        let model = try makeModel()
        model.setLocationKind(.localFile)

        #expect(model.locationKindRaw == ModelLocationKind.localFile.rawValue)
    }
}
