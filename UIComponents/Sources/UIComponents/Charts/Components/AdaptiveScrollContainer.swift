import SwiftUI

// MARK: - Constants

private enum AdaptiveScrollConstants {
    static let macOSMinWidth: CGFloat = 800
    static let visionOSMinWidth: CGFloat = 900
    static let iPadMinWidth: CGFloat = 768
}

/// A scroll container that adapts to different platforms and screen sizes
internal struct AdaptiveScrollContainer<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if os(macOS)
            // macOS: Both vertical and horizontal scrolling with indicators
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                content
                    .frame(minWidth: AdaptiveScrollConstants.macOSMinWidth)
            }
        #elseif os(visionOS)
            // visionOS: Optimized for spatial computing with depth
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(minWidth: AdaptiveScrollConstants.visionOSMinWidth)
            }
        #elseif os(iOS)
            GeometryReader { geometry in
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // iPhone: Vertical scrolling only, full width
                    ScrollView(.vertical, showsIndicators: true) {
                        content
                            .frame(minWidth: geometry.size.width)
                    }
                } else {
                    // iPad: Adaptive scrolling based on orientation
                    if horizontalSizeClass == .regular, verticalSizeClass == .regular {
                        // iPad landscape: Allow horizontal scrolling if needed
                        ScrollView([.vertical, .horizontal], showsIndicators: true) {
                            content
                                .frame(
                                    minWidth: max(
                                        AdaptiveScrollConstants.iPadMinWidth,
                                        geometry.size.width
                                    )
                                )
                        }
                    } else {
                        // iPad portrait or split view
                        ScrollView(.vertical, showsIndicators: true) {
                            content
                                .frame(minWidth: geometry.size.width)
                        }
                    }
                }
            }
        #else
            // Fallback for any other platform
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                content
            }
        #endif
    }
}
