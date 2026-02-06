// swiftlint:disable file_length
import Abstractions
import Database
import Foundation
import ModelDownloader
import OSLog

/// Coordinates model loading and state synchronization between LLMSession and Database
internal final actor ModelStateCoordinator {
    internal static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "ModelStateCoordinator"
    )

    private let database: DatabaseProtocol
    internal let mlxSession: LLMSession
    internal let ggufSession: LLMSession
    internal let remoteSession: LLMSession?
    private let imageGenerator: ImageGenerating
    internal let modelDownloader: ModelDownloaderProtocol
    private var currentModelId: UUID?
    private var currentSession: LLMSession?
    private var isCurrentModelImage: Bool = false
    internal var currentSecurityScopedURL: URL?

    /// Initialize coordinator with database, LLM sessions, and image generator
    internal init(
        database: DatabaseProtocol,
        mlxSession: LLMSession,
        ggufSession: LLMSession,
        imageGenerator: ImageGenerating,
        modelDownloader: ModelDownloaderProtocol,
        remoteSession: LLMSession? = nil
    ) {
        self.database = database
        self.mlxSession = mlxSession
        self.ggufSession = ggufSession
        self.remoteSession = remoteSession
        self.imageGenerator = imageGenerator
        self.modelDownloader = modelDownloader
    }

    deinit {
        let context: DeinitCleanupContext = DeinitCleanupContext(
            modelId: currentModelId,
            session: currentSession,
            database: database,
            isCurrentModelImage: isCurrentModelImage,
            imageGenerator: imageGenerator,
            securityURL: currentSecurityScopedURL
        )
        Self.scheduleDeinitCleanup(context)
    }

    private struct DeinitCleanupContext {
        let modelId: UUID?
        let session: LLMSession?
        let database: DatabaseProtocol
        let isCurrentModelImage: Bool
        let imageGenerator: ImageGenerating
        let securityURL: URL?
    }

    private static func scheduleDeinitCleanup(_ context: DeinitCleanupContext) {
        Task.detached {
            // Unload current model if one is loaded
            guard let modelId = context.modelId else {
                return
            }

            if context.isCurrentModelImage {
                // Cannot use self methods in deinit, create inline
                try? await context.imageGenerator.unload(model: modelId)
            } else if let session = context.session {
                session.stop()
                await session.unload()
            }

            // Update database state to reflect unloaded
            _ = try? await context.database.write(
                ModelCommands.TransitionRuntimeState(
                    id: modelId,
                    transition: .unload
                )
            )

            context.securityURL?.stopAccessingSecurityScopedResource()
        }
    }

    /// Load model for a specific chat
    internal func load(chatId: UUID) async throws {
        Self.logger.info("Loading model for chat: \(chatId)")

        // Get the language model using command
        let sendableModel: SendableModel = try await database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )

        let modelId: UUID = sendableModel.id
        // Check if already loaded
        if let currentId = currentModelId, currentId == modelId {
            Self.logger.debug("Model \(modelId) already loaded, skipping")
            return
        }

        // Unload current model if different
        if currentModelId != nil {
            Self.logger.info("Unloading current model to load new model: \(modelId)")
            try await unloadCurrent()
        }

        try await loadModel(modelId, chatId: chatId, sendableModel: sendableModel)
    }

    /// Unload the currently loaded model
    internal func unload() async throws {
        guard let modelId = currentModelId else {
            Self.logger.debug("No model loaded, skipping unload")
            return
        }

        Self.logger.info("Unloading model: \(modelId)")
        try await unloadCurrent()
    }

    /// Stream text generation from the loaded model
    internal func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        guard let session = currentSession, let modelId = currentModelId else {
            Self.logger.error("Cannot stream: no model loaded")
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: DatabaseError.modelNotFound)
            }
        }

        return createStreamForSession(session, modelId: modelId, input: input)
    }

    /// Generate images using a CoreML model
    internal func generate(
        model: SendableModel,
        config: ImageConfiguration
    ) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        Self.logger.info("Starting image generation with model: \(model.id)")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performImageGeneration(
                        model: model,
                        config: config,
                        continuation: continuation
                    )
                } catch {
                    Self.logger.error("Image generation failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Stop the current generation
    internal func stop() async throws {
        guard let modelId = currentModelId else {
            Self.logger.warning("No model loaded, nothing to stop")
            return
        }

        Self.logger.info("Stopping generation for model: \(modelId)")

        if isCurrentModelImage {
            // Stop image generation
            try await imageGenerator.stop(model: modelId)
        } else if let session = currentSession {
            // Stop text generation
            session.stop()
        }

        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .stopGeneration)
        )
    }
}

// swiftlint:disable no_grouping_extension
// MARK: - Private Helpers
extension ModelStateCoordinator {
    internal static let defaultContextSize: Int = 2_048
    // swiftlint:disable no_magic_numbers
    private static let bytesPerGigabyte: UInt64 = 1_024 * 1_024 * 1_024
    private static let memoryThresholdSmall: UInt64 = 8 * bytesPerGigabyte
    private static let memoryThresholdMedium: UInt64 = 16 * bytesPerGigabyte
    private static let memoryThresholdLarge: UInt64 = 32 * bytesPerGigabyte
    private static let batchSizeSmall: Int = 512
    private static let batchSizeMedium: Int = 1_024
    private static let batchSizeLarge: Int = 2_048
    private static let batchSizeXL: Int = 4_096
    internal static let defaultBatchSize: Int = batchSizeSmall
    // swiftlint:enable no_magic_numbers

    private func loadModel(_ modelId: UUID, chatId _: UUID, sendableModel: SendableModel) async throws {
        Self.logger.info("Loading model \(modelId) with backend: \(sendableModel.backend.rawValue)")

        try await transitionToLoading(modelId)

        let session: LLMSession = try selectSession(for: sendableModel.backend)

        let config: ProviderConfiguration
        do {
            config = try await createConfiguration(sendableModel: sendableModel)
        } catch {
            await handleConfigurationError(modelId: modelId, error: error)
            throw error
        }

        try await preloadModel(session: session, config: config, modelId: modelId)

        try await transitionToLoaded(modelId)

        currentModelId = modelId
        currentSession = session
        Self.logger.info("Model \(modelId) loaded successfully")
    }

    private func preloadModel(
        session: LLMSession,
        config: ProviderConfiguration,
        modelId: UUID
    ) async throws {
        do {
            for try await _ in await session.preload(configuration: config) {
                // Progress streaming handled here
            }
        } catch {
            stopAccessingSecurityScopedResourceIfNeeded()
            _ = try? await database.write(
                ModelCommands.TransitionRuntimeState(id: modelId, transition: .failLoad)
            )
            throw error
        }
    }

    private func handleConfigurationError(modelId: UUID, error: Error) async {
        if case ModelStateCoordinatorError.modelFileMissing = error {
            _ = try? await database.write(
                ModelCommands.DeleteModelLocation(model: modelId)
            )
        }
        _ = try? await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .failLoad)
        )
    }

    private func createConfiguration(sendableModel: SendableModel) async throws -> ProviderConfiguration {
        // Remote models don't need local file paths
        if sendableModel.backend == .remote {
            return createRemoteConfiguration(sendableModel: sendableModel)
        }

        let localPath: URL = try await resolveModelLocation(sendableModel: sendableModel)
        let compute: ComputeConfiguration = makeComputeConfiguration(
            for: sendableModel,
            preferredBatchSize: getBatchSizeForAppleSilicon()
        )

        return ProviderConfiguration(
            location: localPath,
            authentication: .noAuth,
            modelName: sendableModel.location,
            compute: compute
        )
    }

    nonisolated private func resolveContextSize(for sendableModel: SendableModel) -> Int {
        let contextSize: Int = sendableModel.metadata?.contextLength ?? Self.defaultContextSize
        if contextSize <= 0 {
            Self.logger.warning(
                "Invalid context size \(contextSize) for model \(sendableModel.location) - using default"
            )
            return Self.defaultContextSize
        }
        return contextSize
    }

    nonisolated private func resolveBatchSize(preferredBatchSize: Int, contextSize: Int) -> Int {
        let safePreferred: Int = max(1, preferredBatchSize)
        let safeContext: Int = max(1, contextSize)
        return min(safePreferred, safeContext)
    }

    nonisolated internal func makeComputeConfiguration(
        for sendableModel: SendableModel,
        preferredBatchSize: Int
    ) -> ComputeConfiguration {
        let contextSize: Int = resolveContextSize(for: sendableModel)
        let batchSize: Int = resolveBatchSize(
            preferredBatchSize: preferredBatchSize,
            contextSize: contextSize
        )

        return ComputeConfiguration(
            contextSize: contextSize,
            batchSize: batchSize,
            threadCount: ProcessInfo.processInfo.processorCount
        )
    }

    private func createStreamForSession(
        _ session: LLMSession,
        modelId: UUID,
        input: LLMInput
    ) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.transitionToGenerating(modelId)
                    for try await chunk in await session.stream(input) {
                        continuation.yield(chunk)
                    }
                    try await self.transitionFromGenerating(modelId)
                    continuation.finish()
                } catch {
                    try? await self.transitionFromGenerating(modelId)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func transitionToLoading(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .load)
        )
    }

    private func transitionToLoaded(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .completeLoad)
        )
    }

    private func transitionToGenerating(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .startGeneration)
        )
    }

    private func transitionFromGenerating(_ modelId: UUID) async throws {
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .stopGeneration)
        )
    }

    private func unloadCurrent() async throws {
        guard let modelId = currentModelId else {
            return
        }

        Self.logger.debug("Unloading current model: \(modelId)")

        if isCurrentModelImage {
            try await imageGenerator.unload(model: modelId)
        } else if let session = currentSession {
            await session.unload()
        }

        stopAccessingSecurityScopedResourceIfNeeded()

        try await database.write(
            ModelCommands.TransitionRuntimeState(id: modelId, transition: .unload)
        )
        currentModelId = nil
        currentSession = nil
        isCurrentModelImage = false
    }

    private func performImageGeneration(
        model: SendableModel,
        config: ImageConfiguration,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws {
        if currentModelId != nil {
            try await unloadCurrent()
        }
        try await loadImageModel(model)
        for try await progress in await imageGenerator.generate(model: model, config: config) {
            continuation.yield(progress)
        }
        try await unloadImageModel(model)
        continuation.finish()
    }

    private func loadImageModel(_ model: SendableModel) async throws {
        try await transitionToLoading(model.id)
        for try await _ in await imageGenerator.load(model: model) {
            // Progress updates handled by ImageGenerating
        }
        try await transitionToLoaded(model.id)
        currentModelId = model.id
        currentSession = nil
        isCurrentModelImage = true
    }

    private func unloadImageModel(_ model: SendableModel) async throws {
        try await imageGenerator.unload(model: model.id)
        try await database.write(
            ModelCommands.TransitionRuntimeState(id: model.id, transition: .unload)
        )
        currentModelId = nil
        currentSession = nil
        isCurrentModelImage = false
    }

    /// Selects the appropriate session for the given backend type.
    internal func selectSession(for backend: SendableModel.Backend) throws -> LLMSession {
        switch backend {
        case .gguf:
            return ggufSession

        case .mlx, .coreml:
            return mlxSession

        case .remote:
            guard let session = remoteSession else {
                throw ModelStateCoordinatorError.remoteSessionNotConfigured
            }
            return session
        }
    }

    /// Creates configuration for a remote model.
    internal func createRemoteConfiguration(sendableModel: SendableModel) -> ProviderConfiguration {
        let compute: ComputeConfiguration = makeComputeConfiguration(
            for: sendableModel,
            preferredBatchSize: Self.defaultBatchSize
        )
        return ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: sendableModel.location,
            compute: compute
        )
    }

    /// Resolves the local file path for a model.
    private func resolveModelLocation(sendableModel: SendableModel) async throws -> URL {
        if sendableModel.locationKind == .localFile {
            return try resolveLocalModelLocation(sendableModel: sendableModel)
        }

        guard !sendableModel.location.isEmpty else {
            throw ModelStateCoordinatorError.emptyModelLocation
        }

        guard let localPath = await modelDownloader.getModelLocation(for: sendableModel.location) else {
            throw ModelStateCoordinatorError.modelNotDownloaded(sendableModel.location)
        }

        return localPath
    }

    // Local path resolution helpers are in ModelStateCoordinator+Local.swift

    /// Returns an optimized batch size for Apple Silicon.
    private func getBatchSizeForAppleSilicon() -> Int {
        let memory: UInt64 = ProcessInfo.processInfo.physicalMemory

        if memory >= Self.memoryThresholdLarge {
            return Self.batchSizeXL
        }
        if memory >= Self.memoryThresholdMedium {
            return Self.batchSizeLarge
        }
        if memory >= Self.memoryThresholdSmall {
            return Self.batchSizeMedium
        }
        return Self.batchSizeSmall
    }
}
// swiftlint:enable no_grouping_extension
