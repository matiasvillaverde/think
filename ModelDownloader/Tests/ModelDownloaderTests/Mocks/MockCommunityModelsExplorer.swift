import Abstractions
import Foundation
@testable import ModelDownloader

private struct ModelSnapshot {
    let detectedBackends: [SendableModel.Backend]
    let totalSize: Int64
    let modelType: SendableModel.ModelType
    let modelId: String
    let architecture: Architecture
}

private struct ModelPreviewSnapshot {
    let modelId: String
    let backend: SendableModel.Backend
    let totalSize: Int64
    let safeDirectory: String
}

internal final class MockCommunityModelsExplorer: CommunityModelsExplorerProtocol, @unchecked Sendable {
    var discoverModelResponses: [String: DiscoveredModel] = [:]
    var exploreCommunityResponses: [String: [DiscoveredModel]] = [:]
    var searchPaginatedResponses: [String: ModelPage] = [:]
    var searchByTagsResponses: [String: [DiscoveredModel]] = [:]

    deinit {}

    func getDefaultCommunities() -> [ModelCommunity] {
        ModelCommunity.defaultCommunities
    }

    func exploreCommunity(
        _ community: ModelCommunity,
        query: String?,
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> [DiscoveredModel] {
        try await Task.sleep(nanoseconds: 0)
        let key: String = "\(community.id)|\(query ?? "")|\(sort.rawValue)|\(direction.rawValue)|\(limit)"
        return exploreCommunityResponses[key] ?? []
    }

    func discoverModel(_ modelId: String) async throws -> DiscoveredModel {
        try await Task.sleep(nanoseconds: 0)
        if let model = discoverModelResponses[modelId] {
            return model
        }
        throw HuggingFaceError.repositoryNotFound
    }

    // Protocol signature includes many filters; keep for fidelity in tests.
    // swiftlint:disable:next function_parameter_count
    func searchPaginated(
        query: String?,
        author: String?,
        tags: [String],
        cursor: String?,
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> ModelPage {
        try await Task.sleep(nanoseconds: 0)
        let tagKey: String = tags.joined(separator: ",")
        let keyParts: [String] = [
            query ?? "",
            author ?? "",
            tagKey,
            cursor ?? "",
            sort.rawValue,
            direction.rawValue,
            String(limit)
        ]
        let key: String = keyParts.joined(separator: "|")
        return searchPaginatedResponses[key]
            ?? ModelPage(models: [], hasNextPage: false, nextPageToken: nil, totalCount: 0)
    }

    func searchByTags(
        _ tags: [String],
        community: ModelCommunity?,
        sort: SortOption,
        limit: Int
    ) async throws -> [DiscoveredModel] {
        try await Task.sleep(nanoseconds: 0)
        let key: String = "\(tags.sorted().joined(separator: ","))|\(community?.id ?? "")|\(sort.rawValue)|\(limit)"
        return searchByTagsResponses[key] ?? []
    }

    func prepareForDownload(
        _ model: DiscoveredModel,
        preferredBackend: SendableModel.Backend?
    ) async throws -> SendableModel {
        try await Task.sleep(nanoseconds: 0)
        let snapshot: ModelSnapshot = await MainActor.run {
            let detectedBackends: [SendableModel.Backend] = model.detectedBackends
            let totalSize: Int64 = model.files.compactMap(\.size).reduce(0, +)
            let modelType: SendableModel.ModelType = model.inferredModelType ?? .language
            return ModelSnapshot(
                detectedBackends: detectedBackends,
                totalSize: totalSize,
                modelType: modelType,
                modelId: model.id,
                architecture: model.inferredArchitecture
            )
        }

        let backend: SendableModel.Backend
        if let preferredBackend {
            backend = preferredBackend
        } else if let detected = snapshot.detectedBackends.first {
            backend = detected
        } else {
            throw HuggingFaceError.unsupportedFormat
        }

        let ramNeeded: UInt64 = UInt64(max(snapshot.totalSize, 0))
        return SendableModel(
            id: UUID(),
            ramNeeded: ramNeeded,
            modelType: snapshot.modelType,
            location: snapshot.modelId,
            architecture: snapshot.architecture,
            backend: backend,
            locationKind: .huggingFace
        )
    }

    func getModelPreview(_ model: DiscoveredModel) async -> ModelInfo {
        await Task.yield()
        let snapshot: ModelPreviewSnapshot = await MainActor.run {
            let modelId: String = model.id
            let backend: SendableModel.Backend = model.detectedBackends.first ?? .mlx
            let totalSize: Int64 = model.files.compactMap(\.size).reduce(0, +)
            return ModelPreviewSnapshot(
                modelId: modelId,
                backend: backend,
                totalSize: totalSize,
                safeDirectory: modelId.safeDirectoryName
            )
        }
        return ModelInfo(
            id: UUID(),
            name: snapshot.modelId,
            backend: snapshot.backend,
            location: URL(fileURLWithPath: "/tmp/\(snapshot.safeDirectory)"),
            totalSize: snapshot.totalSize,
            downloadDate: Date()
        )
    }

    func populateImages(for model: DiscoveredModel) async throws -> DiscoveredModel {
        try await Task.sleep(nanoseconds: 0)
        return model
    }

    func enrichModel(_ model: DiscoveredModel) async throws -> DiscoveredModel {
        try await Task.sleep(nanoseconds: 0)
        return model
    }

    func enrichModels(_ models: [DiscoveredModel]) async -> [DiscoveredModel] {
        await Task.yield()
        return models
    }
}
