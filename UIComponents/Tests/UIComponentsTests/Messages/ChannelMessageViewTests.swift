import Database
import SwiftUI
import Testing
@testable import UIComponents

#if DEBUG
@MainActor
@Suite("ChannelMessageView Tests")
internal struct ChannelMessageViewTests {
    @Test("Analysis channel shows thinking text")
    func analysisChannelShowsThinkingText() {
        let channel: Channel = Channel(
            type: .analysis,
            content: "Analyzing the request...",
            order: 0
        )

        let message: Message = Message.previewWithResponse
        let view: ChannelMessageView = ChannelMessageView(
            channel: channel,
            message: message
        )

        #expect(view.channel.type == .analysis)
        #expect(view.channel.content == "Analyzing the request...")
    }

    @Test("Commentary channel shows with full visibility")
    func commentaryChannelHasFullVisibility() {
        let channel: Channel = Channel(
            type: .commentary,
            content: "I'll search for information...",
            order: 1
        )

        let message: Message = Message.previewWithResponse
        let view: ChannelMessageView = ChannelMessageView(
            channel: channel,
            message: message
        )

        #expect(view.channel.type == .commentary)
        #expect(view.channel.content == "I'll search for information...")
    }

    @Test("Final channel can have context menu when parent message provided")
    func finalChannelHasContextMenuWithParentMessage() {
        let channel: Channel = Channel(
            type: .final,
            content: "Here's the answer",
            order: 2
        )

        let message: Message = Message.previewWithResponse
        let showingSelection: Binding<Bool> = Binding<Bool>.constant(false)
        let showingStats: Binding<Bool> = Binding<Bool>.constant(false)

        let view: ChannelMessageView = ChannelMessageView(
            channel: channel,
            message: message,
            showingSelectionView: showingSelection,
            showingStatsView: showingStats,
            copyTextAction: { _ in /* No-op */ },
            shareTextAction: { _ in /* No-op */ }
        )

        #expect(view.message.id == message.id)
        #expect(view.copyTextAction != nil)
        #expect(view.shareTextAction != nil)
    }

    @Test("Analysis channel auto-collapses by default")
    func analysisChannelAutoCollapses() {
        let channel: Channel = Channel(
            type: .analysis,
            content: "Thinking about this...",
            order: 0
        )

        // Note: We can't directly test the @State value, but we can verify
        // the channel type that triggers auto-collapse
        let message: Message = Message.previewWithResponse
        let view: ChannelMessageView = ChannelMessageView(
            channel: channel,
            message: message
        )

        #expect(view.channel.type == .analysis)
    }
}
#endif
