import Abstractions
import Foundation
import OSLog

/// Main context builder implementation using Strategy pattern for different architectures
public actor ContextBuilder: ContextBuilding {
    // MARK: - Properties

    private let cache: ProcessingCache = ProcessingCache()
    private let tooling: Tooling
    internal static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "ContextBuilder"
    )

    // MARK: - Constants

    internal enum Constants {
        static let tokensPerCharacterEstimate: Int = 4
        static let previewCharacterLimit: Int = 500
        static let toolResponsePreviewLimit: Int = 100
        static let uuidPrefixLength: Int = 8
        static let toolDescriptionPreviewLimit: Int = 50
    }

    // MARK: - Initialization

    public init(tooling: Tooling) {
        self.tooling = tooling
    }

    // MARK: - ContextBuilding Protocol

    public func build(parameters: BuildParameters) async throws -> String {
        logBuildRequest(parameters)

        // Log detailed action information before fetching tools
        logActionDetails(parameters.action)

        // Configure tools if needed - Just-In-Time configuration
        await configureToolsIfNeeded(parameters.action.tools)

        // Fetch tool definitions from tooling
        let toolDefinitions: [ToolDefinition] = await tooling.getToolDefinitions(
            for: parameters.action.tools
        )

        // Validate that all requested tools are available
        try validateToolAvailability(
            requested: parameters.action.tools,
            available: toolDefinitions
        )

        // Log comparison between requested tools and fetched definitions
        logToolComparison(
            requested: parameters.action.tools,
            fetched: toolDefinitions
        )

        // Create appropriate formatter based on model architecture
        let formatter: ContextFormatter = try FormatterFactory.createFormatter(
            for: parameters.model
        )

        Self.logger.debug("Formatter created: \(String(describing: type(of: formatter)))")

        // Build context using formatter with tool definitions
        let buildContext: BuildContext = BuildContext(
            action: parameters.action,
            contextConfiguration: parameters.contextConfiguration,
            toolResponses: parameters.toolResponses,
            toolDefinitions: toolDefinitions
        )

        let context: String = formatter.build(context: buildContext)

        logBuiltContext(
            context: context,
            parameters: parameters,
            toolDefinitions: toolDefinitions
        )

        return context
    }

    // MARK: - Tool Configuration

    /// Validates that all requested tools are available in the tooling implementation
    private func validateToolAvailability(
        requested: Set<ToolIdentifier>,
        available: [ToolDefinition]
    ) throws {
        // Early return if no tools requested
        guard !requested.isEmpty else {
            return
        }

        // Create set of available tool names
        let availableToolNames: Set<String> = Set(available.map(\.name))

        // Find missing tools by checking if requested tool names are available
        let missingTools: Set<ToolIdentifier> = requested.filter { identifier in
            !availableToolNames.contains(identifier.toolName)
        }

        // Throw error if any tools are missing
        if !missingTools.isEmpty {
            throw ContextBuilderError.toolsNotAvailable(
                requested: requested,
                missing: missingTools
            )
        }
    }

    private func configureToolsIfNeeded(_ tools: Set<ToolIdentifier>) async {
        guard !tools.isEmpty else {
            return
        }

        let toolNames: [String] = tools.map(\.rawValue).sorted()
        Self.logger.info("Configuring tools: \(toolNames.joined(separator: ", "))")
        await tooling.configureTool(identifiers: tools)
        Self.logger.info("Tools configured successfully")
    }

    // MARK: - Logging Helpers

    private func logBuildRequest(_ parameters: BuildParameters) {
        let actionType: String = parameters.action.isTextual
            ? "Text Generation"
            : parameters.action.isVisual ? "Image Generation" : "Unknown"

        let toolsList: String = parameters.action.tools
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")

        let includeDate: String = parameters.contextConfiguration.includeCurrentDate
            ? "yes" : "no"

        Self.logger.debug("""
            ========== BUILD REQUEST START ==========
            Model Configuration:
            - Architecture: \(parameters.model.architecture.rawValue)
            - Model Type: \(parameters.model.modelType.rawValue)
            - Backend: \(parameters.model.backend.rawValue)
            - Location: \(parameters.model.location)
            - Model ID: \(parameters.model.id)
            - RAM Required: \(self.formatBytes(parameters.model.ramNeeded))

            Action Details:
            - Type: \(actionType)
            - Is Reasoning: \(parameters.action.isReasoning)
            - Tools Requested: \(toolsList)

            Context Configuration:
            - Max Prompt Tokens: \(parameters.contextConfiguration.maxPrompt)
            - System Instruction: \(parameters.contextConfiguration.systemInstruction.count) chars
            - Message Count: \(parameters.contextConfiguration.contextMessages.count)
            - Reasoning Level: \(parameters.contextConfiguration.reasoningLevel ?? "none")
            - Include Current Date: \(includeDate)
            - Knowledge Cutoff: \(parameters.contextConfiguration.knowledgeCutoffDate ?? "N/A")

            Tool Responses:
            - Count: \(parameters.toolResponses.count)
            - Has Errors: \(parameters.toolResponses.contains(where: \.isError))
            - Names: \(parameters.toolResponses.map(\.toolName).joined(separator: ", "))
            ========== BUILD REQUEST END ==========
            """)
    }

    private func logBuiltContext(
        context: String,
        parameters: BuildParameters,
        toolDefinitions: [ToolDefinition]
    ) {
        let messageBreakdown: String = formatMessageBreakdown(
            parameters.contextConfiguration.contextMessages
        )

        let toolResponseDetails: String = formatToolResponseDetails(
            parameters.toolResponses
        )

        let estimatedTokens: Int = context.count / Constants.tokensPerCharacterEstimate
        let contextPreview: String = String(context.prefix(Constants.previewCharacterLimit))
        let needsEllipsis: Bool = context.count > Constants.previewCharacterLimit

        Self.logger.debug("""
            ========== BUILT CONTEXT START ==========
            Summary:
            - Total Length: \(context.count) characters
            - Estimated Tokens: ~\(estimatedTokens) (approximate)
            - Tool Definitions Included: \(toolDefinitions.count)
            - Tool Responses Processed: \(parameters.toolResponses.count)

            Message Breakdown:
            \(messageBreakdown.isEmpty ? "  No messages" : messageBreakdown)

            Tool Response Details:
            \(toolResponseDetails.isEmpty ? "  No tool responses" : toolResponseDetails)

            Context Preview (first \(Constants.previewCharacterLimit) chars):
            \(contextPreview)\(needsEllipsis ? "..." : "")

            Full Context:
            \(context)
            ========== BUILT CONTEXT END ==========
            """)
    }

    private func formatMessageBreakdown(_ messages: [MessageData]) -> String {
        messages
            .map { message in
                let userLength: Int = message.userInput?.count ?? 0
                let channelCount: Int = message.channels.count
                let msgId: String = String(message.id.uuidString.prefix(Constants.uuidPrefixLength))
                return "  - ID: \(msgId) | User: \(userLength) | Channels: \(channelCount)"
            }
            .joined(separator: "\n")
    }

    private func formatToolResponseDetails(_ responses: [ToolResponse]) -> String {
        responses
            .map { response in
                let status: String = response.isError ? "❌ Error" : "✅ Success"
                let resultPreview: String = String(
                    response.result.prefix(Constants.toolResponsePreviewLimit)
                )
                let ellipsis: String = response.result.count > Constants.toolResponsePreviewLimit
                    ? "..."
                    : ""
                return "  - \(response.toolName) [\(status)]: \(resultPreview)\(ellipsis)"
            }
            .joined(separator: "\n")
    }

    /// Helper function to format bytes into human-readable format
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    public func process(
        output: String,
        model: SendableModel
    ) async throws -> ProcessedOutput {
        // Check if we have already processed this exact output
        let cachedChannels: [ChannelMessage] = await cache.getCachedChannels(for: output)
        if !cachedChannels.isEmpty {
            // If we have cached channels for this exact output, return them
            return ProcessedOutput(channels: cachedChannels)
        }

        // Create appropriate parser based on model architecture
        let parser: OutputParser = try ParserFactory.createParser(
            for: model,
            cache: cache,
            output: output
        )

        // Parse the output
        let channels: [ChannelMessage] = await parser.parse(output)

        // Update cache
        await cache.update(output, channels: channels)

        return ProcessedOutput(channels: channels)
    }

    public func getStopSequences(model: SendableModel) -> Set<String> {
        do {
            let labels: any StopSequenceLabels = try LabelFactory.createLabels(
                for: model.architecture
            )
            return labels.stopSequence
                .compactMap(\.self)
                .reduce(into: Set<String>()) { result, element in
                    result.insert(element)
                }
        } catch {
            // Return default stop sequences if we can't determine architecture
            return Set(["<|im_end|>", "</s>", "<|eot_id|>", "</end>"])
        }
    }
}
