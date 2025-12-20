import Database
import SwiftUI

// MARK: - SourceRowView

public struct SourceRowView: View {
    let source: Source
    @StateObject private var metadataProvider: MetadataProvider = .init()

    public var body: some View {
        Link(destination: source.url) {
            HStack(alignment: .center, spacing: SourceViewConstants.rowViewSpacing) {
                faviconView

                VStack(alignment: .leading, spacing: SourceViewConstants.rowViewSpacing) {
                    Text(metadataProvider.metadata.title.isEmpty
                        ? source.displayName : metadataProvider.metadata.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(SourceViewConstants.titleMaxLines)

                    Text(source.url.host ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !metadataProvider.metadata.description.isEmpty {
                        Text(metadataProvider.metadata.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(SourceViewConstants.descriptionMaxLines)
                    }
                }
            }
            .padding(.vertical, SourceViewConstants.rowVerticalPadding)
        }
        .onAppear {
            metadataProvider.fetchMetadata(for: source.url)
        }
    }

    private var faviconView: some View {
        Group {
            if let faviconURL = metadataProvider.metadata.faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: SourceViewConstants.iconSize,
                                height: SourceViewConstants.iconSize
                            )
                            .accessibilityLabel(
                                String(
                                    localized: "Website favicon",
                                    bundle: .module
                                )
                            )

                    case .failure, .empty:
                        defaultFaviconView

                    @unknown default:
                        defaultFaviconView
                    }
                }
                .frame(width: SourceViewConstants.iconSize, height: SourceViewConstants.iconSize)
            } else {
                defaultFaviconView
            }
        }
    }

    private var defaultFaviconView: some View {
        Image(systemName: "globe")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: SourceViewConstants.iconSize, height: SourceViewConstants.iconSize)
            .foregroundColor(.secondary)
            .accessibilityLabel(
                String(
                    localized: "Default website icon",
                    bundle: .module
                )
            )
    }
}

#if DEBUG
    #Preview {
        Text("Source Preview")
    }
#endif
