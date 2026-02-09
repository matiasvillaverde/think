import Database
import SwiftData
import SwiftUI

/// A tiny UI-test-only probe that reflects the streaming final channel content even when the
/// corresponding message view is off-screen (LazyVStack not instantiated).
internal struct UITestStreamingProbeView: View {
    @Query private var channels: [Channel]

    internal init() {
        let id: UUID = UITestIDs.shared.scrollStreamingFinalChannelId
        let descriptor: FetchDescriptor<Channel> = FetchDescriptor<Channel>(
            predicate: #Predicate<Channel> { channel in
                channel.id == id
            }
        )
        self._channels = Query(descriptor, animation: .linear(duration: 0))
    }

    internal var body: some View {
        // Keep it visually negligible but still accessible to XCUITest.
        Text(channels.first?.content ?? "")
            .font(.caption2)
            .lineLimit(1)
            .opacity(0.01)
            .accessibilityIdentifier("uiTest.streamingProbe")
    }
}
