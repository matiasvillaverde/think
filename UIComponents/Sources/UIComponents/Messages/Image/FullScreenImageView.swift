import Abstractions
import SwiftUI

// MARK: - Zoomable Full-Screen Image

public struct FullScreenImageView: View {
    let image: PlatformImage

    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0

    public var body: some View {
        zoomableImage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.paletteBlack) // Ensure a black background for a full-screen effect
            .ignoresSafeArea()
    }

    private var zoomableImage: some View {
        Image(platformImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(finalScale * currentScale)
            .accessibilityLabel(
                String(
                    localized: "Image generated that can be zoomed in and out",
                    bundle: .module,
                    comment: "Accessibility label for the full-screen image view"
                )
            )
            #if os(macOS)
            .onDrag {
                NSItemProvider(object: image)
            }
            #elseif os(iOS)
            .onDrag {
                NSItemProvider(object: image)
            }
            #endif
            .gesture(
                MagnificationGesture()
                    .onChanged { scaleDelta in
                        currentScale = scaleDelta
                    }
                    .onEnded { scaleDelta in
                        let newScale: CGFloat = finalScale * scaleDelta
                        // clamp scale to [1, 5]
                        let maxScale: CGFloat = 5
                        finalScale = min(max(newScale, 1.0), maxScale)
                        currentScale = 1.0
                    }
            )
    }
}
