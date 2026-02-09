import SwiftUI

private enum ChartSectionConstants {
    static let chevronFontSize: CGFloat = 14
}

/// A wrapper for chart sections in a List with consistent styling
public struct ChartSection<Content: View>: View {
    let title: String?
    let content: Content

    @State private var isExpanded: Bool = true
    private let showExpandButton: Bool

    public init(
        title: String? = nil,
        expandable: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        showExpandButton = expandable && title != nil
        self.content = content()
    }

    public var body: some View {
        Section {
            if isExpanded {
                content
            }
        } header: {
            if let title {
                sectionHeader(title: title)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: ChartConstants.Typography.sectionHeaderSize, weight: .bold))
                .foregroundColor(Color.textPrimary)

            Spacer()

            if showExpandButton {
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
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(
                            .system(
                                size: ChartSectionConstants.chevronFontSize,
                                weight: .semibold
                            )
                        )
                        .foregroundColor(Color.textSecondary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, ChartConstants.Layout.itemSpacing)
    }
}

/// A dashboard view that uses List layout for charts
public struct ChartsDashboardList<Content: View>: View {
    let content: Content

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            if shouldUseMultiColumn(width: geometry.size.width) {
                multiColumnLayout
            } else {
                singleColumnLayout
            }
        }
    }

    private var singleColumnLayout: some View {
        List {
            content
                .listRowInsets(EdgeInsets(
                    top: ChartConstants.Layout.itemSpacing,
                    leading: ChartConstants.Layout.horizontalPadding,
                    bottom: ChartConstants.Layout.itemSpacing,
                    trailing: ChartConstants.Layout.horizontalPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.paletteClear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var multiColumnLayout: some View {
        ScrollView {
            LazyVGrid(
                columns: adaptiveColumns,
                spacing: ChartConstants.Layout.sectionSpacing
            ) {
                content
            }
            .padding(ChartConstants.Layout.horizontalPadding)
        }
    }

    private var adaptiveColumns: [GridItem] {
        #if os(iOS)
            if horizontalSizeClass == .regular {
                return [
                    GridItem(
                        .flexible(
                            minimum: ChartConstants.Grid.minColumnWidth,
                            maximum: ChartConstants.Grid.maxColumnWidth
                        )
                    ),
                    GridItem(
                        .flexible(
                            minimum: ChartConstants.Grid.minColumnWidth,
                            maximum: ChartConstants.Grid.maxColumnWidth
                        )
                    )
                ]
            }
            return [GridItem(.flexible())]
        #elseif os(macOS)
            return [
                GridItem(.flexible(
                    minimum: ChartConstants.Grid.minColumnWidth,
                    maximum: ChartConstants.Grid.maxColumnWidth
                )),
                GridItem(.flexible(
                    minimum: ChartConstants.Grid.minColumnWidth,
                    maximum: ChartConstants.Grid.maxColumnWidth
                ))
            ]
        #else
            return [GridItem(.flexible())]
        #endif
    }

    private func shouldUseMultiColumn(width: CGFloat) -> Bool {
        #if os(iOS)
            let iPadBreakpoint: CGFloat = 768
            return horizontalSizeClass == .regular && width > iPadBreakpoint
        #elseif os(macOS)
            let macBreakpoint: CGFloat = 900
            return width > macBreakpoint
        #else
            return false
        #endif
    }
}
