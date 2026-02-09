import SwiftUI

private enum ChartCardConstants {
    static let offsetDivisor: CGFloat = 2
    static let zeroOffset: CGFloat = 0
    static let shadowYOffset: CGFloat = 2
}

/// A reusable card container for charts with consistent styling
public struct ChartCard<Content: View, Controls: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let content: Content
    let controls: Controls?

    @State private var isExpanded: Bool = true
    @State private var hasAppeared: Bool = false
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder controls: () -> Controls? = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
        self.controls = controls()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.cardSpacing) {
            // Header
            headerView
                .opacity(hasAppeared ? 1 : 0)
                .offset(
                    y: hasAppeared
                        ? ChartCardConstants.zeroOffset
                        : -ChartConstants.Layout.sectionSpacing / ChartCardConstants.offsetDivisor
                )

            if isExpanded {
                // Chart Content
                content
                    .frame(minHeight: ChartConstants.Layout.minChartHeight)
                    .frame(height: adaptiveChartHeight)
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(
                        hasAppeared ? 1 : ChartConstants.Styling.initialScale
                    )

                // Controls (if provided)
                if controls != nil {
                    Divider()
                        .opacity(ChartConstants.Styling.separatorOpacity)
                        .opacity(hasAppeared ? 1 : 0)

                    controls
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(
                            y: hasAppeared
                                ? ChartCardConstants.zeroOffset
                                : ChartConstants.Layout.sectionSpacing /
                                    ChartCardConstants.offsetDivisor
                        )
                }
            }
        }
        .padding(ChartConstants.Layout.cardPadding)
        .background(ChartConstants.Styling.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ChartConstants.Styling.cornerRadius)
                .stroke(
                    ChartConstants.Styling.cardBorder,
                    lineWidth: ChartConstants.Styling.borderWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: ChartConstants.Styling.cornerRadius))
        .shadow(
            color: Color.paletteBlack.opacity(ChartConstants.Styling.shadowOpacity),
            radius: ChartConstants.Styling.shadowRadius,
            x: ChartCardConstants.zeroOffset,
            y: ChartCardConstants.shadowYOffset
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : ChartConstants.Layout.sectionSpacing)
        .onAppear {
            withAnimation(
                .spring(
                    response: ChartConstants.Styling.entryAnimationResponse,
                    dampingFraction: ChartConstants.Styling.entryAnimationDamping
                )
            ) {
                hasAppeared = true
            }
        }
    }

    private var headerView: some View {
        HStack {
            headerTitleSection
            Spacer()
            expandCollapseButton
        }
    }

    private var headerTitleSection: some View {
        HStack(spacing: ChartConstants.Layout.itemSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(
                        .system(size: ChartConstants.Typography.chartTitleSize)
                    )
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
            }

            headerTextContent
        }
    }

    private var headerTextContent: some View {
        VStack(
            alignment: .leading,
            spacing: ChartConstants.Layout.itemSpacing / ChartCardConstants.offsetDivisor
        ) {
            Text(title)
                .font(
                    .system(
                        size: ChartConstants.Typography.chartTitleSize,
                        weight: .semibold
                    )
                )
                .foregroundColor(Color.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(
                        .system(size: ChartConstants.Typography.chartSubtitleSize)
                    )
                    .foregroundColor(Color.textSecondary)
            }
        }
    }

    private var expandCollapseButton: some View {
        Button {
            withAnimation(
                .spring(
                    response: ChartConstants.Styling.springResponse,
                    dampingFraction: ChartConstants.Styling.springDamping
                )
            ) {
                isExpanded.toggle()
            }
        } label: {
            Image(
                systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle"
            )
            .font(
                .system(size: ChartConstants.Typography.sectionHeaderSize)
            )
            .foregroundColor(Color.textSecondary)
            .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
        }
        .buttonStyle(.plain)
    }

    private var adaptiveChartHeight: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return ChartConstants.Layout.compactChartHeight
            }
        #endif
        return ChartConstants.Layout.chartHeight
    }
}

// MARK: - Extension for charts without controls

/// Extension for ChartCard without control section
extension ChartCard where Controls == EmptyView {
    /// Initialize chart card without controls
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
        controls = nil
    }
}
