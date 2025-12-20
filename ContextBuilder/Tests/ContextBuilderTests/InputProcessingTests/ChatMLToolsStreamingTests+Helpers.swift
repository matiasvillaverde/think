import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

// MARK: - Helper Extensions

extension ChatMLToolsStreamingTests {
    // MARK: - Helper Types

    internal struct StreamingState {
        var previousCommentaryContent = ""
        var previousToolContent = ""
        var hasSeenCommentaryChannel = false
        var hasSeenToolChannel = false
        var toolChannelCount = 0
        // NEW: UUID identity tracking
        var channelUUIDs: [ChannelMessage.ChannelType: UUID] = [:]
        var seenUUIDs: Set<UUID> = []
    }

    // MARK: - Test Constants

    internal enum TestConstants {
        static let testRAMNeeded: UInt64 = 1_000_000_000
        static let expectedToolChannelCount: Int = 2
    }

    // MARK: - Test Helpers

    internal func createTestModel(architecture: Architecture) -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: TestConstants.testRAMNeeded,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )
    }

    internal func loadToolsInputContent() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "input_chatml_tools",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("input_chatml_tools.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    internal func processChannels(
        output: ProcessedOutput,
        accumulatedInput: String,
        streamState: inout StreamingState,
        position: Int
    ) {
        let commentaryChannel = output.channels.first { $0.type == .commentary }
        let toolChannels = output.channels.filter { $0.type == .tool }

        // NEW: Verify all channels have valid UUIDs
        verifyChannelUUIDIdentities(
            channels: output.channels,
            streamState: &streamState,
            position: position
        )

        if let commentary = commentaryChannel {
            streamState.hasSeenCommentaryChannel = true
            verifyCommentaryChannel(
                commentary: commentary,
                accumulatedInput: accumulatedInput,
                previousContent: streamState.previousCommentaryContent,
                position: position
            )
            streamState.previousCommentaryContent = commentary.content
        }

        // Process tool channels (there could be multiple)
        if !toolChannels.isEmpty {
            streamState.hasSeenToolChannel = true
            streamState.toolChannelCount = toolChannels.count

            for toolChannel in toolChannels {
                verifyToolChannel(
                    tool: toolChannel,
                    hasSeenCommentary: streamState.hasSeenCommentaryChannel,
                    position: position
                )
            }
        }
    }

    internal func verifyCommentaryChannel(
        commentary: ChannelMessage,
        accumulatedInput: String,
        previousContent: String,
        position: Int
    ) {
        let hasCompleteCommentaryTag = accumulatedInput.contains("<commentary>")
        #expect(
            hasCompleteCommentaryTag,
            "Commentary channel should only appear after complete <commentary> tag at \(position)"
        )

        verifyProgressiveChannelContent(
            current: commentary.content,
            previous: previousContent,
            channelType: "commentary",
            position: position
        )

        #expect(
            !commentary.content.contains("<commentary>") &&
                !commentary.content.contains("</commentary>"),
            "Commentary content should not contain commentary tags at position \(position)"
        )
    }

    internal func verifyToolChannel(
        tool: ChannelMessage,
        hasSeenCommentary: Bool,
        position: Int
    ) {
        // Commentary should appear before tool calls
        #expect(
            hasSeenCommentary,
            "Should have seen commentary channel before tool channel at position \(position)"
        )

        // Verify tool has required properties
        #expect(
            tool.toolRequest != nil,
            "Tool channel should have toolRequest at position \(position)"
        )

        let hasValidRecipient = tool.recipient?.starts(with: "functions.") ?? false
        #expect(
            hasValidRecipient,
            "Tool channel should have proper recipient at position \(position)"
        )
    }

    internal func verifyPartialTagHandling(
        _ output: ProcessedOutput,
        accumulatedInput: String,
        position: Int
    ) {
        // Check for partial commentary tag scenarios
        let hasPartialCommentaryTag = checkPartialCommentaryTag(accumulatedInput)
        let hasOpenCommentaryWithoutClose = accumulatedInput.contains("<commentary>") &&
            !accumulatedInput.contains("</commentary>")

        // Check for partial tool_call tag scenarios
        let hasPartialToolTag = checkPartialToolTag(accumulatedInput)
        let hasOpenToolWithoutClose = accumulatedInput.contains("<tool_call>") &&
            !accumulatedInput.contains("</tool_call>")

        let commentaryChannel = output.channels.first { $0.type == .commentary }
        let toolChannel = output.channels.first { $0.type == .tool }

        if hasPartialCommentaryTag, !accumulatedInput.contains("<commentary>") {
            // Partial opening tag - should have no commentary channel
            #expect(
                commentaryChannel == nil,
                "No commentary channel with partial opening tag at position \(position)"
            )
        } else if hasOpenCommentaryWithoutClose {
            // Has complete opening but no closing - check if there's actual content
            let trimmedContent = accumulatedInput
                .replacingOccurrences(of: "<commentary>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContent.isEmpty {
                // Should have commentary channel only if there's non-whitespace content
                #expect(
                    commentaryChannel != nil,
                    "Should have commentary channel for streaming content at position \(position)"
                )
            } else {
                // Should NOT have commentary channel for whitespace-only content
                #expect(
                    commentaryChannel == nil,
                    "Should not have commentary channel for whitespace-only at position \(position)"
                )
            }
        }

        if hasPartialToolTag, !accumulatedInput.contains("<tool_call>") {
            // Partial opening tag - should have no tool channel
            #expect(
                toolChannel == nil,
                "Should not have tool channel with partial opening tag at position \(position)"
            )
        } else if hasOpenToolWithoutClose {
            // Has opening but no closing - should have no tool channel yet
            #expect(
                toolChannel == nil,
                "Should not have tool channel without closing tag at position \(position)"
            )
        }
    }

    private func checkPartialCommentaryTag(_ input: String) -> Bool {
        input.hasSuffix("<") ||
            input.hasSuffix("<c") ||
            input.hasSuffix("<co") ||
            input.hasSuffix("<com") ||
            input.hasSuffix("<comm") ||
            input.hasSuffix("<comme") ||
            input.hasSuffix("<commen") ||
            input.hasSuffix("<comment") ||
            input.hasSuffix("<commenta") ||
            input.hasSuffix("<commentar") ||
            input.hasSuffix("<commentary")
    }

    private func checkPartialToolTag(_ input: String) -> Bool {
        input.hasSuffix("<t") ||
            input.hasSuffix("<to") ||
            input.hasSuffix("<too") ||
            input.hasSuffix("<tool") ||
            input.hasSuffix("<tool_") ||
            input.hasSuffix("<tool_c") ||
            input.hasSuffix("<tool_ca") ||
            input.hasSuffix("<tool_cal") ||
            input.hasSuffix("<tool_call")
    }

    internal func verifyProgressiveChannelContent(
        current: String,
        previous: String,
        channelType: String,
        position: Int
    ) {
        // Content should either grow, stay the same, or be cleaned (partial tags removed)
        // When partial closing tags are excluded, content might shrink
        let isGrowing = current.hasPrefix(previous) ||
            current == previous ||
            previous.hasPrefix(current) // Allow shrinking when cleaning occurs
        #expect(
            isGrowing,
            """
            \(channelType) channel content should progressively grow at position \(position).
            Previous: "\(previous)"
            Current: "\(current)"
            """
        )
    }

    internal func verifyFinalToolsOutput(
        contextBuilder: ContextBuilder,
        model: SendableModel,
        inputContent: String,
        streamState: StreamingState
    ) async throws {
        let finalOutput = try await contextBuilder.process(
            output: inputContent,
            model: model
        )

        // Should have exactly 2 channels in final output (commentary + tool)
        #expect(
            finalOutput.channels.count == TestConstants.expectedToolChannelCount,
            "Final output should have exactly 2 channels (commentary and tool)"
        )

        // Verify we saw both channels during streaming
        #expect(
            streamState.hasSeenCommentaryChannel,
            "Should have seen commentary channel during streaming"
        )
        #expect(
            streamState.hasSeenToolChannel,
            "Should have seen tool channel during streaming"
        )

        // Verify channel ordering - commentary should come before tool
        let sortedChannels = finalOutput.channels.sorted { $0.order < $1.order }
        if sortedChannels.count == TestConstants.expectedToolChannelCount {
            #expect(
                sortedChannels[0].type == .commentary,
                "First channel should be commentary"
            )
            #expect(
                sortedChannels[1].type == .tool,
                "Second channel should be tool"
            )

            // Verify tool properties
            let toolChannel = sortedChannels[1]
            #expect(
                toolChannel.toolRequest?.name == "weather",
                "Tool should be weather function"
            )
            #expect(
                toolChannel.recipient == "functions.weather",
                "Tool recipient should be functions.weather"
            )
        }
    }

    // MARK: - UUID Identity Verification

    internal func verifyChannelUUIDIdentities(
        channels: [ChannelMessage],
        streamState: inout StreamingState,
        position: Int
    ) {
        for channel in channels {
            // Verify channel has a valid UUID (not nil/empty)
            let channelId = channel.id
            #expect(
                channelId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"),
                "Channel should have a valid UUID at position \(position)"
            )

            // Check UUID consistency for channel type
            if let existingUuid = streamState.channelUUIDs[channel.type] {
                #expect(
                    channel.id == existingUuid,
                    """
                    Channel UUID consistency violation at position \(position)!
                    Channel type: \(channel.type)
                    Expected UUID: \(existingUuid)
                    Actual UUID: \(channel.id)
                    This means the same channel type got different UUIDs during streaming.
                    """
                )
            } else {
                // First time seeing this channel type - store its UUID
                streamState.channelUUIDs[channel.type] = channel.id
            }

            // Track all UUIDs to verify uniqueness across different types
            if streamState.seenUUIDs.contains(channel.id) {
                // This UUID was already used by a different channel type
                let conflictingType = streamState.channelUUIDs.first { $1 == channel.id }?.key
                if let conflictingType, conflictingType != channel.type {
                    #expect(
                        false,
                        """
                        UUID collision detected at position \(position)!
                        Channel type \(channel.type) has UUID \(channel.id)
                        But this UUID was already used by channel type \(conflictingType)
                        Different channel types must have different UUIDs.
                        """
                    )
                }
            } else {
                streamState.seenUUIDs.insert(channel.id)
            }
        }

        // Verify all channels in this output have unique UUIDs
        let allUUIDs = channels.map(\.id)
        let uniqueUUIDs = Set(allUUIDs)
        #expect(
            allUUIDs.count == uniqueUUIDs.count,
            """
            Duplicate UUIDs within single output at position \(position)!
            Total channels: \(allUUIDs.count)
            Unique UUIDs: \(uniqueUUIDs.count)
            This means multiple channels in the same output share UUIDs.
            """
        )
    }
}
