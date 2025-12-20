import Abstractions
import SwiftUI

// MARK: - Constants

private enum FullScreenConstants {
    // Spacing
    static let vStackSpacing: CGFloat = 0
    static let standardPadding: CGFloat = 16

    // UI Elements
    static let bottomBarHeight: CGFloat = 80
    static let bottomBarOpacity: Double = 0.5

    // Colors
    static let backgroundColor: Color = .black
}

// MARK: - Full-Screen Content

public struct FullScreenSheetContent: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction
    @Environment(\.imageHandler)
    var viewModel: ViewModelImaging

    let imageData: Data
    @State private var toast: Toast?

    public var body: some View {
        if let platformImage = dataToPlatformImage(imageData) {
            VStack(spacing: FullScreenConstants.vStackSpacing) {
                closeButton
                Spacer()
                imageContent(platformImage: platformImage)
                Spacer()
                actionBar(platformImage: platformImage)
            }
            .background(FullScreenConstants.backgroundColor)
            .toastView(toast: $toast)
        } else {
            invalidImageView
        }
    }

    // MARK: - Private View Components

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(
                String(
                    localized: "Close",
                    bundle: .module,
                    comment: "Close button label"
                )
            ) {
                dismiss()
            }
            .padding(FullScreenConstants.standardPadding)
        }
    }

    private func imageContent(platformImage: PlatformImage) -> some View {
        FullScreenImageView(image: platformImage)
            .padding(FullScreenConstants.standardPadding)
    }

    private func actionBar(platformImage: PlatformImage) -> some View {
        HStack {
            Spacer()

            Button {
                viewModel.savePlatformImage(platformImage)
                toast = Toast(
                    style: .success,
                    message: String(
                        localized: "Saved!",
                        bundle: .module,
                        comment: "Saved toast message"
                    )
                )
            } label: {
                Label(
                    String(
                        localized: "Save",
                        bundle: .module,
                        comment: "Button label for saving an image"
                    ),
                    systemImage: "square.and.arrow.down"
                )
            }

            Spacer()

            copiedButton(platformImage: platformImage)

            Spacer()
        }
        .background(
            FullScreenConstants.backgroundColor.opacity(FullScreenConstants.bottomBarOpacity)
        )
        .frame(height: FullScreenConstants.bottomBarHeight)
        .padding(FullScreenConstants.standardPadding)
        .padding(.bottom) // Extra padding at the bottom
    }

    private func copiedButton(platformImage: PlatformImage) -> some View {
        Button {
            viewModel.copyPlatformImage(platformImage)
            toast = Toast(
                style: .success,
                message: String(
                    localized: "Copied!",
                    bundle: .module,
                    comment: "Copied toast message"
                )
            )
        } label: {
            Label(
                String(
                    localized: "Copy",
                    bundle: .module,
                    comment: "Button label for copying an image"
                ),
                systemImage: "doc.on.doc"
            )
        }
    }

    private var invalidImageView: some View {
        VStack {
            Text(String(localized: "Invalid image data.", bundle: .module))
            Button(
                String(
                    localized: "Close",
                    bundle: .module,
                    comment: "Close button label"
                )
            ) { dismiss() }
        }
        .padding(FullScreenConstants.standardPadding)
    }
}
