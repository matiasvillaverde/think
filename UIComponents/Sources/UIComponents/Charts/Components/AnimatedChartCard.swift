import SwiftUI

private enum AnimatedChartCardConstants {
    static let animationOffset: CGFloat = 30
}

/// Wrapper for ChartCard with staggered animation support
public struct AnimatedChartCard<Content: View, Controls: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let animationIndex: Int
    let content: Content
    let controls: Controls?

    @State private var hasAppeared: Bool = false

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        animationIndex: Int = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder controls: () -> Controls? = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.animationIndex = animationIndex
        self.content = content()
        self.controls = controls()
    }

    public var body: some View {
        ChartCard(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            content
        } controls: {
            controls
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : AnimatedChartCardConstants.animationOffset)
        .onAppear {
            let delay: Double = Double(animationIndex) * ChartConstants.Styling.staggerDelay

            withAnimation(
                .spring(
                    response: ChartConstants.Styling.entryAnimationResponse,
                    dampingFraction: ChartConstants.Styling.entryAnimationDamping
                )
                .delay(delay)
            ) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Extension for charts without controls

extension AnimatedChartCard where Controls == EmptyView {
    /// Convenience initializer for charts without control elements
    /// - Parameters:
    ///   - title: Chart title
    ///   - subtitle: Optional chart subtitle
    ///   - systemImage: Optional SF Symbol name
    ///   - animationIndex: Index for staggered animation timing
    ///   - content: Chart content view builder
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        animationIndex: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.animationIndex = animationIndex
        self.content = content()
        controls = nil
    }
}
