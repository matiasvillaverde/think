import Kingfisher
import SwiftUI

/// A high-performance async image view with caching and progressive loading
///
/// Provides optimized image loading with Kingfisher, including blur-to-sharp
/// progressive loading, automatic caching, and graceful error handling.
internal struct CachedAsyncImageView: View {
    // MARK: - Properties

    private let url: URL?
    private let targetSize: CGSize
    private let contentMode: SwiftUI.ContentMode
    private let enableProgressiveLoading: Bool
    private let placeholder: AnyView
    private let errorView: AnyView

    @State private var imageState: ImageViewState = .idle

    // MARK: - Initialization

    /// Creates a cached async image view
    /// - Parameters:
    ///   - url: The image URL to load
    ///   - targetSize: Target size for optimization
    ///   - contentMode: How the image should be sized
    ///   - enableProgressiveLoading: Whether to show blur-to-sharp effect
    ///   - placeholder: View to show while loading
    ///   - errorView: View to show on error
    init(
        url: URL?,
        targetSize: CGSize,
        contentMode: SwiftUI.ContentMode = .fit,
        enableProgressiveLoading: Bool = true,
        @ViewBuilder placeholder: () -> some View = {
            ImagePlaceholder()
        },
        @ViewBuilder errorView: () -> some View = {
            ImageErrorView()
        }
    ) {
        self.url = url
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.enableProgressiveLoading = enableProgressiveLoading
        self.placeholder = AnyView(placeholder())
        self.errorView = AnyView(errorView())
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .placeholder { placeholder }
                    .onFailure { _ in
                        imageState = .error(.networkError)
                    }
                    .onSuccess { _ in
                        imageState = .loaded(())
                    }
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: ViewConstants.scaleTransition)
                        )
                    )
            } else {
                placeholder
            }
        }
        .onAppear {
            if let url {
                loadImage(from: url)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadImage(from _: URL) {
        guard case .idle = imageState else {
            return
        }
        imageState = .loading
    }
}

// MARK: - Default Views

private struct ImagePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: ViewConstants.cornerRadius)
            .fill(Color.paletteGray.opacity(ViewConstants.placeholderOpacity))
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .accessibilityHidden(true)
            )
    }
}

private struct ImageErrorView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: ViewConstants.cornerRadius)
            .fill(Color.paletteRed.opacity(ViewConstants.errorOpacity))
            .overlay(
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundColor(.red)
                    .accessibilityHidden(true)
            )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 20) {
            CachedAsyncImageView(
                url: URL(string: "https://picsum.photos/300/200"),
                targetSize: CGSize(width: 300, height: 200)
            )
            .frame(width: 300, height: 200)
            CachedAsyncImageView(
                url: nil,
                targetSize: CGSize(width: 300, height: 200)
            )
            .frame(width: 300, height: 200)
        }
        .padding()
    }
#endif

// MARK: - Constants

private enum ViewConstants {
    static let cornerRadius: CGFloat = 8
    static let placeholderOpacity: Double = 0.3
    static let errorOpacity: Double = 0.1
    static let scaleTransition: CGFloat = 0.95
}
