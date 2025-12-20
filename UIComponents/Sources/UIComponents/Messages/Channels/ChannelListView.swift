import Abstractions
import Database
import SwiftUI

/// A view that displays multiple channels in order
internal struct ChannelListView: View {
    // MARK: - Constants

    private enum Constants {
        static let listSpacing: CGFloat = 12
        static let emptyStateSpacing: CGFloat = 16
    }

    // MARK: - Properties

    internal let channels: [Channel]
    internal let filter: Channel.ChannelType?

    // MARK: - Computed Properties

    internal var filteredChannels: [Channel] {
        guard let filter else {
            return channels
        }
        return channels.filter { $0.type == filter }
    }

    internal var showsEmptyState: Bool {
        channels.isEmpty
    }

    // MARK: - Initialization

    internal init(channels: [Channel], filter: Channel.ChannelType? = nil) {
        self.channels = channels
        self.filter = filter
    }

    // MARK: - Body

    internal var body: some View {
        if showsEmptyState {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Constants.listSpacing) {
                    ForEach(sortedChannels) { channel in
                        ChannelView(channel: channel)
                            .transition(.asymmetric(
                                insertion: .slide.combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding()
            }
        }
    }

    private var sortedChannels: [Channel] {
        filteredChannels.sorted { $0.order < $1.order }
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.emptyStateSpacing) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text("No channels to display")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Channel List") {
        let channels: [Channel] = [
            Channel(
                type: .analysis,
                content: "Analyzing the request...",
                order: 0,
                isComplete: true
            ),
            Channel(
                type: .tool,
                content: "Executing calculation...",
                order: 1,
                toolExecution: ToolExecution(
                    request: ToolRequest(
                        name: "calculator",
                        arguments: "{\"expression\": \"42 * 3.14159\"}",
                        displayName: "Calculator"
                    ),
                    state: .completed
                ),
                isComplete: true
            ),
            Channel(
                type: .final,
                content: "The result is **131.95**",
                order: 2,
                isComplete: true
            )
        ]

        ChannelListView(channels: channels)
    }

    #Preview("Empty State") {
        ChannelListView(channels: [])
    }
#endif
