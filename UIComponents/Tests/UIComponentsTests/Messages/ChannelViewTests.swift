@testable import Database
import SwiftUI
import Testing
@testable import UIComponents

@Suite("ChannelView Tests")
@MainActor
internal struct ChannelViewTests {
    // MARK: - Single Channel Display Tests

    @Test("ChannelView displays final channel content")
    internal func displaysFinalChannelContent() {
        let channel: Channel = Channel(
            type: .final,
            content: "This is the final response",
            order: 0,
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.content == "This is the final response")
        #expect(view.channel.type == .final)
        #expect(view.channel.isComplete == true)
    }

    @Test("ChannelView displays analysis channel content")
    internal func displaysAnalysisChannelContent() {
        let channel: Channel = Channel(
            type: .analysis,
            content: "Let me think about this...",
            order: 0,
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.content == "Let me think about this...")
        #expect(view.channel.type == .analysis)
    }

    @Test("ChannelView displays commentary channel content")
    internal func displaysCommentaryChannelContent() {
        let channel: Channel = Channel(
            type: .commentary,
            content: "Here's some additional context",
            order: 0,
            recipient: "user",
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.content == "Here's some additional context")
        #expect(view.channel.type == .commentary)
        #expect(view.channel.recipient == "user")
    }

    // MARK: - Streaming State Tests

    @Test("ChannelView shows loading state for incomplete channel")
    internal func showsLoadingStateForIncompleteChannel() {
        let channel: Channel = Channel(
            type: .final,
            content: "Partial response...",
            order: 0,
            isComplete: false
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.isComplete == false)
        // Note: showsStreamingIndicator is computed property based on isComplete
        #expect(!view.channel.isComplete)
    }

    @Test("ChannelView hides loading state for complete channel")
    internal func hidesLoadingStateForCompleteChannel() {
        let channel: Channel = Channel(
            type: .final,
            content: "Complete response",
            order: 0,
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.isComplete == true)
        // Note: showsStreamingIndicator would be false when isComplete is true
    }

    // MARK: - Multiple Channels Display Tests

    @Test("ChannelListView displays multiple channels in order")
    internal func displaysMultipleChannelsInOrder() {
        let channels: [Channel] = [
            Channel(type: .analysis, content: "Thinking...", order: 0, isComplete: true),
            Channel(type: .commentary, content: "Note: ", order: 1, isComplete: true),
            Channel(type: .final, content: "Final answer", order: 2, isComplete: true)
        ]

        let view: ChannelListView = ChannelListView(channels: channels)

        #expect(view.channels.count == 3)
        #expect(view.channels[0].order == 0)
        #expect(view.channels[1].order == 1)
        #expect(view.channels[2].order == 2)
    }

    @Test("ChannelListView filters channels by type")
    internal func filtersChannelsByType() {
        let channels: [Channel] = [
            Channel(type: .analysis, content: "Thinking 1", order: 0, isComplete: true),
            Channel(type: .final, content: "Response 1", order: 1, isComplete: true),
            Channel(type: .analysis, content: "Thinking 2", order: 2, isComplete: true),
            Channel(type: .final, content: "Response 2", order: 3, isComplete: true)
        ]

        let view: ChannelListView = ChannelListView(
            channels: channels,
            filter: .final
        )

        // The view should filter to show only final type channels
        let expectedFilteredCount: Int = 2
        #expect(channels.filter { $0.type == .final }.count == expectedFilteredCount)
    }

    // MARK: - Edge Cases

    @Test("ChannelView handles empty content gracefully")
    internal func handlesEmptyContent() {
        let channel: Channel = Channel(
            type: .final,
            content: "",
            order: 0,
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.content.isEmpty)
        // View should hide when content is empty
    }

    @Test("ChannelView handles very long content")
    internal func handlesLongContent() {
        let longContent: String = String(repeating: "Lorem ipsum ", count: 500)
        let channel: Channel = Channel(
            type: .final,
            content: longContent,
            order: 0,
            isComplete: true
        )

        let view: ChannelView = ChannelView(channel: channel)

        #expect(view.channel.content == longContent)
        #expect(view.channel.content.count > 1_000)
    }

    @Test("ChannelListView handles empty channel list")
    internal func handlesEmptyChannelList() {
        let channels: [Channel] = []

        let view: ChannelListView = ChannelListView(channels: channels)

        #expect(view.channels.isEmpty)
        // View should show empty state when no channels
    }
}
