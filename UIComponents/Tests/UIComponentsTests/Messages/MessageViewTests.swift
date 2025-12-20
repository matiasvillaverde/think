import Database
import SwiftUI
import Testing
@testable import UIComponents

#if DEBUG
@MainActor
@Suite("MessageView Backward Compatibility Tests")
internal struct MessageViewTests {
    @Test("MessageView initializes with preview message")
    func initializesWithPreviewMessage() {
        // Use a preview message which already has properties set
        let message: Message = Message.previewWithResponse

        let view: MessageView = MessageView(message: message)

        // Verify the view is created with the message
        #expect(view.message.userInput != nil)
        #expect(view.message.response != nil)
    }

    @Test("MessageView handles response without channels")
    func handlesResponseWithoutChannels() {
        // Use a preview message that has response but no channels
        let message: Message = Message.previewWithResponse

        let view: MessageView = MessageView(message: message)

        // Verify the view is created with the correct message
        #expect(view.message.response != nil)
        #expect(view.message.channels != nil)  // Now using channels internally
    }

    @Test("MessageView handles preview with thinking")
    func handlesPreviewWithThinking() {
        // Use a preview message with thinking
        let message: Message = Message.previewWithThinking

        let view: MessageView = MessageView(message: message)

        // Verify thinking content exists
        #expect(view.message.thinking != nil)
        #expect(view.message.response != nil)
    }

    @Test("MessageView handles preview with user image")
    func handlesPreviewWithUserImage() {
        // Use a preview message with user image
        let message: Message = Message.previewWithUserImage

        let view: MessageView = MessageView(message: message)

        // Verify user image exists
        #expect(view.message.userImage != nil)
        #expect(view.message.userInput != nil)
    }

    @Test("MessageView handles preview with response image")
    func handlesPreviewWithResponseImage() {
        // Use a preview message with response image
        let message: Message = Message.previewWithResponseImage

        let view: MessageView = MessageView(message: message)

        // Verify response image exists
        #expect(view.message.responseImage != nil)
        #expect(view.message.response != nil)
    }

    @Test("MessageView handles preview with file")
    func handlesPreviewWithFile() {
        // Use a preview message with file attachment
        let message: Message = Message.previewWithFile

        let view: MessageView = MessageView(message: message)

        // Verify file attachment exists
        #expect(view.message.file != nil)
        #expect(view.message.file?.isEmpty == false)
    }

    @Test("MessageView handles complex conversation")
    func handlesComplexConversation() {
        // Use a preview message with complex conversation
        let message: Message = Message.previewComplexConversation

        let view: MessageView = MessageView(message: message)

        // Verify complex conversation content
        #expect(view.message.userInput != nil)
        #expect(view.message.response != nil)
        #expect(view.message.thinking != nil)
    }

    @Test("MessageView handles all preview types")
    func handlesAllPreviewTypes() {
        // Test that all preview messages can be displayed
        let messages: [Message] = Message.allPreviews

        for message in messages {
            let view: MessageView = MessageView(message: message)
            #expect(view.message == message)
        }
    }
}
#endif
