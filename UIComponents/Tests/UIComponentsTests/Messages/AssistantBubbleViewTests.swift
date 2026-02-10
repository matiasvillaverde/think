import Database
import SwiftUI
import Testing
@testable import UIComponents

#if DEBUG
@MainActor
@Suite("AssistantBubbleView Backward Compatibility Tests")
internal struct AssistantBubbleViewTests {
    @Test("AssistantBubbleView initializes with preview message")
    func initializesWithPreviewMessage() {
        // Use a preview message
        let message: Message = Message.previewWithResponse

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op for test */ },
            shareTextAction: { _ in /* No-op for test */ }
        )

        // Verify the view is created with the correct message
        #expect(view.message.channels?.contains { $0.type == .final } == true)
    }

    @Test("AssistantBubbleView handles thinking message")
    func handlesThinkingMessage() {
        // Use a preview message with thinking
        let message: Message = Message.previewWithThinking

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op for test */ },
            shareTextAction: { _ in /* No-op for test */ }
        )

        // Verify the message has analysis + final channels
        #expect(view.message.channels?.contains { $0.type == .analysis } == true)
        #expect(view.message.channels?.contains { $0.type == .final } == true)
    }

    @Test("AssistantBubbleView handles complex conversation")
    func handlesComplexConversation() {
        // Use a preview message with complex conversation
        let message: Message = Message.previewComplexConversation

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op for test */ },
            shareTextAction: { _ in /* No-op for test */ }
        )

        // Verify the message has all expected content
        #expect(view.message.userInput != nil)
        #expect(view.message.channels?.contains { $0.type == .analysis } == true)
        #expect(view.message.channels?.contains { $0.type == .final } == true)
    }

    @Test("AssistantBubbleView handles code messages")
    func handlesCodeMessages() {
        // Use a preview message with code
        let message: Message = Message.codeMessages

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op for test */ },
            shareTextAction: { _ in /* No-op for test */ }
        )

        // Verify code message content
        let finalText: String? = view.message.channels?.first { $0.type == .final }?.content
        #expect(finalText != nil)
        #expect(finalText?.contains("```") == true)
    }

    @Test("AssistantBubbleView handles image messages")
    func handlesImageMessages() {
        // Use a preview message with image
        let message: Message = Message.imageMessages

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op for test */ },
            shareTextAction: { _ in /* No-op for test */ }
        )

        // Verify image message has response image
        #expect(view.message.responseImage != nil)
        #expect(view.message.channels?.contains { $0.type == .final } == true)
    }

    @Test("AssistantBubbleView handles all preview types")
    func handlesAllPreviewTypes() {
        // Test that all preview messages can be displayed
        let messages: [Message] = Message.allPreviews

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        for message in messages {
            let view: AssistantBubbleView = AssistantBubbleView(
                message: message,
                showingSelectionView: showingSelection,
                showingStatsView: showingStats,
                copyTextAction: { _ in /* No-op for test */ },
                shareTextAction: { _ in /* No-op for test */ }
            )
            #expect(view.message == message)
        }
    }

    @Test("AssistantBubbleView copy and share actions")
    func copyAndShareActions() {
        let message: Message = Message.previewWithResponse

        let showingSelection: Binding<Bool> = .constant(false)
        let showingStats: Binding<Bool> = .constant(false)

        var copiedText: String = ""
        var sharedText: String = ""

        let view: AssistantBubbleView = AssistantBubbleView(
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { text in copiedText = text },
            shareTextAction: { text in sharedText = text }
        )

        // Call the actions
        view.copyTextAction("test copy")
        view.shareTextAction("test share")

        // Verify actions were called
        #expect(copiedText == "test copy")
        #expect(sharedText == "test share")
    }
}
#endif
