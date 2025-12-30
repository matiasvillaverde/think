import Abstractions
@testable import Database
import Foundation
import Testing
@testable import Tools

@Suite("ToolValidator Tests")
internal struct ToolValidatorTests {
    @Test("Image tool requires download when model is not downloaded")
    func imageToolRequiresDownloadWhenMissing() async throws {
        let model: Model = try createImageModel(state: .notDownloaded, ramNeeded: 1_024, size: 10_000)
        let database: ToolValidatorTestDatabase = ToolValidatorTestDatabase(
            imageModel: model.toSendable(),
            downloadInfo: ModelCommands.ModelDownloadInfo(
                id: model.id,
                state: model.state ?? .notDownloaded,
                size: model.size,
                ramNeeded: model.ramNeeded
            )
        )

        let validator: ToolValidator = ToolValidator(
            database: database,
            healthKitAvailability: MockHealthKitAvailability(available: false)
        )

        let result: ToolValidationResult = try await validator.validateToolRequirements(
            .imageGeneration,
            chatId: UUID()
        )

        if case let .requiresDownload(modelId, size) = result {
            #expect(modelId == model.id)
            #expect(size == model.size)
        } else {
            Issue.record("Expected requiresDownload, got \(result)")
        }
    }

    @Test("Image tool reports insufficient memory when model exceeds available memory")
    func imageToolInsufficientMemory() async throws {
        let available: UInt64 = ProcessInfo.processInfo.physicalMemory
        let model: Model = try createImageModel(
            state: .downloaded,
            ramNeeded: available + 1,
            size: 10_000
        )
        let database: ToolValidatorTestDatabase = ToolValidatorTestDatabase(
            imageModel: model.toSendable(),
            downloadInfo: ModelCommands.ModelDownloadInfo(
                id: model.id,
                state: model.state ?? .notDownloaded,
                size: model.size,
                ramNeeded: model.ramNeeded
            )
        )

        let validator: ToolValidator = ToolValidator(
            database: database,
            healthKitAvailability: MockHealthKitAvailability(available: false)
        )

        let result: ToolValidationResult = try await validator.validateToolRequirements(
            .imageGeneration,
            chatId: UUID()
        )

        if case let .insufficientMemory(required, availableMemory) = result {
            #expect(required == model.ramNeeded)
            #expect(availableMemory == available)
        } else {
            Issue.record("Expected insufficientMemory, got \(result)")
        }
    }

    @Test("Image tool is available when model is downloaded and memory is sufficient")
    func imageToolAvailableWhenReady() async throws {
        let model: Model = try createImageModel(state: .downloaded, ramNeeded: 1, size: 10_000)
        let database: ToolValidatorTestDatabase = ToolValidatorTestDatabase(
            imageModel: model.toSendable(),
            downloadInfo: ModelCommands.ModelDownloadInfo(
                id: model.id,
                state: model.state ?? .notDownloaded,
                size: model.size,
                ramNeeded: model.ramNeeded
            )
        )

        let validator: ToolValidator = ToolValidator(
            database: database,
            healthKitAvailability: MockHealthKitAvailability(available: true)
        )

        let result: ToolValidationResult = try await validator.validateToolRequirements(
            .imageGeneration,
            chatId: UUID()
        )

        #expect(result.isAvailable)
    }

    @Test("HealthKit tool returns notSupported when HealthKit unavailable")
    func healthKitNotSupportedWhenUnavailable() async throws {
        let model: Model = try createImageModel(state: .downloaded, ramNeeded: 1, size: 1)
        let database: ToolValidatorTestDatabase = ToolValidatorTestDatabase(
            imageModel: model.toSendable(),
            downloadInfo: ModelCommands.ModelDownloadInfo(
                id: model.id,
                state: model.state ?? .notDownloaded,
                size: model.size,
                ramNeeded: model.ramNeeded
            )
        )
        let validator: ToolValidator = ToolValidator(
            database: database,
            healthKitAvailability: MockHealthKitAvailability(available: false)
        )

        let result: ToolValidationResult = try await validator.validateToolRequirements(
            .healthKit,
            chatId: UUID()
        )
        if case .notSupported = result {
            // expected
        } else {
            Issue.record("Expected notSupported, got \(result)")
        }
    }

    private func createImageModel(
        state: Model.State,
        ramNeeded: UInt64,
        size: UInt64
    ) throws -> Model {
        let model: Model = try Model(
            type: .diffusion,
            backend: .coreml,
            name: "ImageModel",
            displayDescription: "Test image model",
            parameters: 1,
            ramNeeded: ramNeeded,
            size: size,
            locationHuggingface: "test/image-model",
            architecture: .unknown
        )
        model.state = state
        return model
    }
}

private actor ToolValidatorTestDatabase: DatabaseProtocol {
    private let imageModel: SendableModel
    private let downloadInfo: ModelCommands.ModelDownloadInfo

    init(imageModel: SendableModel, downloadInfo: ModelCommands.ModelDownloadInfo) {
        self.imageModel = imageModel
        self.downloadInfo = downloadInfo
    }

    @MainActor var status: DatabaseStatus { .ready }

    @MainActor
    func write<T: WriteCommand>(_: T) async throws -> T.Result {
        await Task.yield()
        throw ToolError("Unsupported write")
    }

    @MainActor
    func read<T: ReadCommand>(_ command: T) async throws -> T.Result {
        await Task.yield()
        if command is ChatCommands.GetImageModel {
            guard let result = imageModel as? T.Result else {
                throw ToolError("Unsupported read command")
            }
            return result
        }
        if command is ModelCommands.GetModelDownloadInfo {
            guard let result = downloadInfo as? T.Result else {
                throw ToolError("Unsupported read command")
            }
            return result
        }
        throw ToolError("Unsupported read command")
    }

    @MainActor
    func execute<T: AnonymousCommand>(_: T) async throws -> T.Result {
        await Task.yield()
        throw ToolError("Unsupported execute")
    }

    @MainActor
    func save() throws {
        if false {
            throw ToolError("Unexpected")
        }
        // No-op for tests.
    }

    func writeInBackground<T: WriteCommand>(_: T) async throws {
        await Task.yield()
        throw ToolError("Unsupported background write")
    }

    func readInBackground<T: ReadCommand>(_: T) async throws -> T.Result {
        await Task.yield()
        throw ToolError("Unsupported background read")
    }

    func semanticSearch(
        query _: String,
        table _: String,
        numResults _: Int,
        threshold _: Double
    ) async throws -> [SearchResult] {
        await Task.yield()
        throw ToolError("Unsupported semantic search")
    }

    func indexText(
        _: String,
        id _: UUID,
        table _: String
    ) async throws {
        await Task.yield()
        throw ToolError("Unsupported index")
    }

    func deleteFromIndex(
        id _: UUID,
        table _: String
    ) async throws {
        await Task.yield()
        throw ToolError("Unsupported delete")
    }

    func searchMemories(
        query _: String,
        userId _: UUID,
        limit _: Int,
        threshold _: Double
    ) async throws -> [UUID] {
        await Task.yield()
        throw ToolError("Unsupported memory search")
    }
}

private struct MockHealthKitAvailability: HealthKitAvailabilityChecking {
    let available: Bool

    func isAvailable() -> Bool {
        available
    }
}
