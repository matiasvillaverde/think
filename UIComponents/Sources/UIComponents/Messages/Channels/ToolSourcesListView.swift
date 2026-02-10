import Abstractions
import Database
import SwiftUI

/// A view that displays a list of sources associated with a tool execution
internal struct ToolSourcesListView: View {
    // MARK: - Constants

    private enum Constants {
        static let spacing: CGFloat = 6
        static let iconSize: CGFloat = 12
        static let cornerRadius: CGFloat = 6
        static let padding: CGFloat = 8
        static let backgroundOpacity: Double = 0.05
        static let borderOpacity: Double = 0.1
        static let borderWidth: CGFloat = 0.5
        static let maxSourcesShown: Int = 5
        static let animationDuration: Double = 0.2
        static let chevronSize: CGFloat = 10
        static let sourceLinkSpacing: CGFloat = 4
        static let headerFontSize: CGFloat = 11
        static let headerSpacing: CGFloat = 4
        static let sourceRowItemSpacing: CGFloat = 2
        static let iconOpacity: Double = 0.7
        static let secondaryIconOpacity: Double = 0.5
        static let animationResponse: Double = 0.3
        static let animationDamping: Double = 0.8
        static let iconSizeReduction: CGFloat = 2
    }

    // MARK: - Properties

    let sources: [Source]
    @State private var isExpanded: Bool = false

    // MARK: - Computed Properties

    private var displayedSources: [Source] {
        if isExpanded || sources.count <= Constants.maxSourcesShown {
            return sources
        }
        return Array(sources.prefix(Constants.maxSourcesShown))
    }

    private var hasMoreSources: Bool {
        sources.count > Constants.maxSourcesShown && !isExpanded
    }

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            headerView

            VStack(alignment: .leading, spacing: Constants.sourceLinkSpacing) {
                ForEach(displayedSources, id: \.id) { source in
                    sourceRow(source)
                }

                if hasMoreSources {
                    showMoreButton
                }
            }
        }
        .padding(Constants.padding)
        .background(backgroundView)
        .overlay(borderOverlay)
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: isExpanded
        )
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: Constants.headerSpacing) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(Color.textSecondary)
                .accessibilityHidden(true)

            Text("Sources (\(sources.count))", bundle: .module)
                .font(.system(size: Constants.headerFontSize, weight: .semibold))
                .foregroundColor(Color.textSecondary)
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: Source) -> some View {
        HStack(spacing: Constants.sourceLinkSpacing) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(.blue.opacity(Constants.iconOpacity))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Constants.sourceRowItemSpacing) {
                Text(source.displayName)
                    .font(.caption)
                    .foregroundColor(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(source.url.absoluteString)
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: Constants.iconSize - Constants.iconSizeReduction))
                .foregroundColor(.secondary.opacity(Constants.secondaryIconOpacity))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openURL(source.url)
        }
        .accessibilityAddTraits(.isLink)
        .accessibilityLabel(
            Text("\(source.displayName), opens in browser", bundle: .module)
        )
    }

    private var showMoreButton: some View {
        Button {
            withAnimation(
                .spring(
                    response: Constants.animationResponse,
                    dampingFraction: Constants.animationDamping
                )
            ) {
                isExpanded = true
            }
        } label: {
            HStack(spacing: Constants.headerSpacing) {
                Text(
                    "Show \(sources.count - Constants.maxSourcesShown) more",
                    bundle: .module
                )
                    .font(.caption2)
                    .foregroundColor(.blue)

                Image(systemName: "chevron.down")
                    .font(.system(size: Constants.chevronSize))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.paletteBlue.opacity(Constants.backgroundOpacity))
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .stroke(
                Color.paletteBlue.opacity(Constants.borderOpacity),
                lineWidth: Constants.borderWidth
            )
    }

    // MARK: - Actions

    private func openURL(_ url: URL) {
        #if os(iOS) || os(visionOS)
            UIApplication.shared.open(url)
        #elseif os(macOS)
            NSWorkspace.shared.open(url)
        #endif
    }
}
