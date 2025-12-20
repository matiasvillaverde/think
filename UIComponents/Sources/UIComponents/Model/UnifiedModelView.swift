import Abstractions
import Database
import SwiftUI

/// A unified SwiftUI view that displays both Model and DiscoveredModel entities
///
/// This view provides a reusable component that can display either a local Model
/// or a DiscoveredModel from the discovery API, with different display modes
/// (small/large) and appropriate UI based on the model's current state.
internal struct UnifiedModelView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: UnifiedModelViewModel

    // MARK: - Constants

    private let iconSizeSmall: CGFloat = 16
    private let iconSizeLarge: CGFloat = 24
    private let animationDuration: Double = 0.2
    private let tagsMaxCount: Int = 6
    private let tagsColumns: Int = 3
    private let progressViewScale: CGFloat = 0.8

    // MARK: - Initialization

    /// Initialize with a Model entity
    /// - Parameters:
    ///   - model: The Model entity to display
    ///   - displayMode: The display mode (default: .large)
    internal init(model: Model, displayMode: UnifiedModelViewModel.DisplayMode = .large) {
        viewModel = UnifiedModelViewModel(model: model, displayMode: displayMode)
    }

    /// Initialize with a DiscoveredModel entity
    /// - Parameters:
    ///   - discoveredModel: The DiscoveredModel entity to display
    ///   - displayMode: The display mode (default: .large)
    internal init(
        discoveredModel: DiscoveredModel,
        displayMode: UnifiedModelViewModel.DisplayMode = .large
    ) {
        viewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel,
            displayMode: displayMode
        )
    }

    // MARK: - Body

    internal var body: some View {
        Group {
            if viewModel.isSmallMode {
                smallModeView
            } else {
                largeModeView
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: viewModel.isLoading)
        .animation(.easeInOut(duration: animationDuration), value: viewModel.errorMessage != nil)
    }

    // MARK: - Small Mode View

    @ViewBuilder private var smallModeView: some View {
        VStack(alignment: .center, spacing: DesignConstants.Spacing.medium) {
            // Image or icon
            modelImageView

            // Title
            Text(viewModel.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(DesignConstants.Font.lineLimit)
                .foregroundColor(.primary)

            // Author
            Text(viewModel.author)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Error state
            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            }

            // Loading state
            if viewModel.isLoading {
                loadingView
            }
        }
        .padding(DesignConstants.Spacing.medium)
    }

    // MARK: - Large Mode View

    @ViewBuilder private var largeModeView: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.standard) {
            largeModeHeader
            largeModeContent
        }
        .padding(DesignConstants.Spacing.standard)
    }

    @ViewBuilder private var largeModeHeader: some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.standard) {
            modelImageView

            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                // Title
                Text(viewModel.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(DesignConstants.Font.lineLimit)

                // Author
                Text(viewModel.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Backend and size info
                HStack(spacing: DesignConstants.Spacing.medium) {
                    Label(viewModel.backendType, systemImage: "cpu")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(viewModel.formattedSize, systemImage: "externaldrive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder private var largeModeContent: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.standard) {
            // Tags
            if !viewModel.tags.isEmpty {
                tagsView
            }

            // Error state
            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            }

            // Loading state
            if viewModel.isLoading {
                loadingView
            }

            // Download button (only in large mode)
            if viewModel.shouldShowDownloadButton {
                downloadButtonView
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var modelImageView: some View {
        Group {
            if let imageURL = viewModel.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .accessibilityLabel(
                            Text("Model image for \(viewModel.title)", bundle: .module)
                        )
                } placeholder: {
                    modelIconPlaceholder
                }
            } else {
                modelIconPlaceholder
            }
        }
        .frame(
            width: viewModel.isSmallMode
                ? DesignConstants.Size.iconMedium
                : DesignConstants.Size.emptyStateIcon,
            height: viewModel.isSmallMode
                ? DesignConstants.Size.iconMedium
                : DesignConstants.Size.emptyStateIcon
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Radius.small))
    }

    @ViewBuilder private var modelIconPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
            .fill(Color.secondary.opacity(DesignConstants.Opacity.backgroundSubtle))
            .overlay(
                Image(systemName: "cube.box")
                    .font(.system(size: viewModel.isSmallMode ? iconSizeSmall : iconSizeLarge))
                    .foregroundColor(.secondary)
                    .accessibilityLabel(Text("Model icon", bundle: .module))
            )
    }

    @ViewBuilder private var tagsView: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: DesignConstants.Spacing.small),
                count: tagsColumns
            ),
            spacing: DesignConstants.Spacing.small
        ) {
            ForEach(viewModel.tags.prefix(tagsMaxCount), id: \.self) { tag in
                tagView(tag: tag)
            }
        }
    }

    @ViewBuilder
    private func tagView(tag: String) -> some View {
        Text(tag)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, DesignConstants.Spacing.medium)
            .padding(.vertical, DesignConstants.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                    .fill(Color.accentColor)
            )
            .lineLimit(1)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
                .accessibilityLabel(Text("Error", bundle: .module))

            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(DesignConstants.Font.lineLimit)
        }
        .padding(DesignConstants.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                .fill(Color.red.opacity(DesignConstants.Opacity.backgroundSubtle))
        )
    }

    @ViewBuilder private var loadingView: some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            ProgressView()
                .scaleEffect(progressViewScale)

            Text("Loading...", bundle: .module)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignConstants.Spacing.small)
    }

    @ViewBuilder private var downloadButtonView: some View {
        switch viewModel.modelInput {
        case let .model(model):
            ModelActionButton(model: model)

        case let .discovered(discoveredModel):
            ModelActionButton(discoveredModel: discoveredModel)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("UnifiedModelView - Large Mode with Model") {
        VStack(spacing: DesignConstants.Spacing.large) {
            UnifiedModelView(model: Model.preview, displayMode: .large)
            UnifiedModelView(model: Model.preview, displayMode: .small)
        }
        .padding()
    }

    #Preview("UnifiedModelView - DiscoveredModel") {
        @Previewable @State var discoveredModel: DiscoveredModel = {
            let model: DiscoveredModel = DiscoveredModel(
                id: "microsoft/DialoGPT-medium",
                name: "DialoGPT Medium",
                author: "Microsoft",
                downloads: 50_000,
                likes: 1_200,
                tags: ["conversational", "text-generation", "pytorch", "dialogue"],
                lastModified: Date(),
                files: [
                    ModelFile(path: "pytorch_model.bin", size: 500_000_000),
                    ModelFile(path: "config.json", size: 1_500),
                    ModelFile(path: "vocab.json", size: 898_000)
                ],
                license: "MIT",
                licenseUrl: "https://opensource.org/licenses/MIT"
            )
            model.detectedBackends = [.mlx, .gguf]
            return model
        }()

        VStack(spacing: DesignConstants.Spacing.large) {
            UnifiedModelView(discoveredModel: discoveredModel, displayMode: .large)
            UnifiedModelView(discoveredModel: discoveredModel, displayMode: .small)
        }
        .padding()
    }

    #Preview("UnifiedModelView - Loading and Error States") {
        VStack(spacing: DesignConstants.Spacing.large) {
            UnifiedModelView(model: Model.preview, displayMode: .large)
                .onAppear {
                    // Simulate loading state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
                            model: Model.preview
                        )
                        viewModel.setLoading(true)
                    }
                }

            UnifiedModelView(model: Model.preview, displayMode: .large)
                .onAppear {
                    // Simulate error state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
                            model: Model.preview
                        )
                        viewModel.setError("Failed to load model information")
                    }
                }
        }
        .padding()
    }
#endif
