import Abstractions
import SwiftUI

/// Image gallery section for discovery model detail view
internal struct DiscoveryModelDetailImageGallery: View {
    // MARK: - Properties

    private let imageUrls: [URL]
    private let modelName: String

    // MARK: - Initialization

    init(imageUrls: [URL], modelName: String) {
        self.imageUrls = imageUrls
        self.modelName = modelName
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("Images", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if imageUrls.count == 1, let url = imageUrls.first {
                // Single image display - simplified for now
                simpleImageView(url)
            } else if imageUrls.count > 1 {
                // Multiple images carousel - simplified for now
                simpleImageCarousel
            }
        }
    }

    // MARK: - Subviews

    private func simpleImageView(_ url: URL) -> some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .fill(Color.backgroundSecondary)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                        .accessibilityHidden(true)
                )
        }
        .frame(maxHeight: GalleryLayout.maxImageHeight)
        .background(Color.backgroundSecondary)
        .cornerRadius(DesignConstants.Radius.standard)
    }

    private var simpleImageCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.Spacing.large) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                            .fill(Color.backgroundSecondary)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.textSecondary)
                                    .accessibilityHidden(true)
                            )
                    }
                    .frame(
                        width: GalleryLayout.carouselImageWidth,
                        height: GalleryLayout.carouselImageHeight
                    )
                    .background(Color.backgroundSecondary)
                    .cornerRadius(DesignConstants.Radius.standard)
                    .accessibilityLabel(
                        Text("Image \(index + 1) of \(imageUrls.count)", bundle: .module)
                    )
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
        }
    }
}

// MARK: - Constants

private enum GalleryLayout {
    static let maxImageHeight: CGFloat = 300
    static let imageWidth: CGFloat = 600
    static let imageHeight: CGFloat = 400
    static let imageSize: CGSize = .init(width: imageWidth, height: imageHeight)
    static let carouselImageWidth: CGFloat = 250
    static let carouselImageHeight: CGFloat = 167
    static let carouselImageSize: CGSize = .init(
        width: carouselImageWidth,
        height: carouselImageHeight
    )
}

// MARK: - Preview

#if DEBUG
    #Preview {
        DiscoveryModelDetailImageGallery(
            imageUrls: [
                URL(string: "https://picsum.photos/600/400"),
                URL(string: "https://picsum.photos/600/401"),
                URL(string: "https://picsum.photos/600/402")
            ].compactMap(\.self),
            modelName: "Test Model"
        )
        .padding()
    }
#endif
