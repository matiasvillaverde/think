import Abstractions
import CoreGraphics
import Database
import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Efficient Message Persistor

internal final actor MessagePersistor {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "MessagePersistor"
    )

    internal let database: DatabaseProtocol
    private let placeholderGenerator: PlaceholderImageGenerating

    internal init(
        database: DatabaseProtocol,
        placeholderGenerator: PlaceholderImageGenerating? = nil
    ) {
        self.database = database
        let config: AgentOrchestratorConfiguration.PlaceholderImage =
            AgentOrchestratorConfiguration.shared.placeholderImage
        self.placeholderGenerator = placeholderGenerator ?? PlaceholderImageGenerator(
            size: config.defaultSize,
            gradientStartRed: config.gradientStartRed,
            gradientStartGreen: config.gradientStartGreen,
            gradientStartBlue: config.gradientStartBlue,
            gradientEndBlue: config.gradientEndBlue
        )
    }

    internal func createMessage(chatId: UUID, prompt: String, model: SendableModel) async throws
    -> UUID {
        let isDeepThinker: Bool = model.modelType == .deepLanguage

        Self.logger.debug("Creating message for chat: \(chatId, privacy: .private)")
        Self.logger.debug("User prompt length: \(prompt.count) chars, model: \(model.id, privacy: .private)")

        let messageId: UUID = try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: prompt,
                isDeepThinker: isDeepThinker
            )
        )

        Self.logger.debug("Message created with ID: \(messageId, privacy: .private)")
        return messageId
    }

    internal func updateMessage(messageId: UUID, output: ProcessedOutput) async throws {
        // Update everything using the UpdateProcessedOutput command
        try await database.write(
            MessageCommands.UpdateProcessedOutput(
                messageId: messageId,
                processedOutput: output
            )
        )
    }

    internal func saveToolResults(messageId: UUID, results: [ToolResponse]) async throws {
        Self.logger.debug("Saving tool results for message: \(messageId, privacy: .private)")
        Self.logger.debug("Tool results count: \(results.count)")

        try await database.write(
            MessageCommands.UpdateToolResponses(
                messageId: messageId,
                toolResponses: results
            )
        )

        Self.logger.debug("Tool results saved successfully")
    }

    internal func saveStatistics(messageId: UUID, metrics: ChunkMetrics) async throws {
        Self.logStatistics(messageId: messageId, metrics: metrics)

        // Save only Metrics (Statistics removed)
        try await saveMetrics(messageId: messageId, metrics: metrics)

        Self.logger.debug("Metrics saved successfully")
    }

    internal func saveMetrics(messageId: UUID, metrics: ChunkMetrics) async throws {
        try await database.write(
            MetricsCommands.Add(messageId: messageId, metrics: metrics)
        )
    }

    private static func logStatistics(messageId: UUID, metrics: ChunkMetrics) {
        logger.debug("Saving statistics for message: \(messageId, privacy: .private)")
        logger.debug("Metrics - tokens/sec: \(metrics.timing?.tokensPerSecond ?? 0.0)")
        logger.debug("Metrics - generated: \(metrics.usage?.generatedTokens ?? 0)")
        logger.debug("Metrics - prompt: \(metrics.usage?.promptTokens ?? 0)")
    }

    internal func createImageMessage(
        chatId: UUID,
        prompt: String,
        model: SendableModel
    ) async throws -> UUID {
        // Create the message
        let messageId: UUID = try await createMessage(chatId: chatId, prompt: prompt, model: model)

        // Add placeholder image if we can create one
        if let placeholderData = placeholderGenerator.generatePlaceholderData() {
            let imageConfig: ImageConfiguration = try await database.read(
                ImageCommands.GetImageConfiguration(chat: chatId, prompt: prompt)
            )

            try await database.write(
                ImageCommands.AddResponse(
                    messageId: messageId,
                    imageData: placeholderData,
                    configuration: imageConfig.id,
                    prompt: prompt
                )
            )
        }

        return messageId
    }

    internal func updateGeneratedImage(
        messageId: UUID,
        cgImage: CGImage,
        configurationId: UUID,
        prompt: String,
        imageMetrics: ImageMetrics?
    ) async throws {
        try await saveGeneratedImage(
            messageId: messageId,
            cgImage: cgImage,
            configurationId: configurationId,
            prompt: prompt
        )

        if let metrics = imageMetrics {
            try await saveImageMetrics(messageId: messageId, metrics: metrics)
        }
    }

    private func saveGeneratedImage(
        messageId: UUID,
        cgImage: CGImage,
        configurationId: UUID,
        prompt: String
    ) async throws {
        try await database.write(
            ImageCommands.AddImageResponse(
                messageId: messageId,
                cgImage: cgImage,
                configuration: configurationId,
                prompt: prompt
            )
        )
    }

    private func saveImageMetrics(
        messageId: UUID,
        metrics: ImageMetrics
    ) async throws {
        let chunkMetrics: ChunkMetrics = convertImageMetricsToChunkMetrics(metrics)
        try await saveMetrics(messageId: messageId, metrics: chunkMetrics)
    }

    private func convertImageMetricsToChunkMetrics(_ metrics: ImageMetrics) -> ChunkMetrics {
        let timing: TimingMetrics? = convertImageTimingToChunkTiming(metrics.timing)
        let usage: UsageMetrics? = convertImageUsageToChunkUsage(metrics.usage)
        return ChunkMetrics(timing: timing, usage: usage, generation: nil)
    }

    private func convertImageTimingToChunkTiming(_ imageTiming: ImageTimingMetrics?) -> TimingMetrics? {
        guard let imageTime = imageTiming else {
            return nil
        }
        return TimingMetrics(
            totalTime: imageTime.totalTime,
            timeToFirstToken: imageTime.promptEncodingTime,
            timeSinceLastToken: nil,
            tokenTimings: [],
            promptProcessingTime: imageTime.promptEncodingTime
        )
    }

    private func convertImageUsageToChunkUsage(_ imageUsage: ImageUsageMetrics?) -> UsageMetrics? {
        guard let usage = imageUsage else {
            return nil
        }
        return UsageMetrics(
            generatedTokens: 0,
            totalTokens: usage.promptTokens ?? 0,
            promptTokens: usage.promptTokens,
            contextWindowSize: nil,
            contextTokensUsed: nil,
            kvCacheBytes: nil,
            kvCacheEntries: nil
        )
    }
}

// MARK: - Channel Type Conversion

extension ChannelMessage.ChannelType {
    /// Convert ChannelMessage.ChannelType to Channel.ChannelType
    internal func toChannelType() -> Channel.ChannelType {
        switch self {
        case .analysis:
            return .analysis

        case .commentary:
            return .commentary

        case .final:
            return .final

        case .tool:
            return .tool
        }
    }
}
