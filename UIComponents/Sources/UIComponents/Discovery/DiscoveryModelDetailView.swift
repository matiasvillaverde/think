import Abstractions
import Kingfisher
import OSLog
import SwiftUI

/// A detailed view for displaying discovered model information
internal struct DiscoveryModelDetailView: View {
    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    #if os(macOS)
        @Environment(\.openWindow)
        private var openWindow: OpenWindowAction
    #endif

    // MARK: - Properties

    private let model: DiscoveredModel
    private let logger: Logger = .init(
        subsystem: "UIComponents",
        category: "DiscoveryModelDetailView"
    )

    // MARK: - State

    @State private var showingFullDescription: Bool = false
    @State private var showingSafariView: Bool = false
    @State private var safariURL: URL?
    @State private var hasStartedDownload: Bool = false

    // MARK: - Initialization

    internal init(model: DiscoveredModel) {
        self.model = model
    }

    // MARK: - Body

    internal var body: some View {
        ScrollView {
            mainContent
                .padding()
        }
        .navigationTitle(Text("Model Details", bundle: .module))
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(String(localized: "Done", bundle: .module)) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSafariView) {
                if let url = safariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            headerSection

            imageGallerySection

            Divider()
            DiscoveryModelStatsSection(model: model)

            Divider()

            if let cardData = model.cardData {
                MetadataSection.fromCardData(
                    title: String(localized: "Model Details", bundle: .module),
                    cardData: cardData
                )

                Divider()
                MetadataSection.technicalSpecs(from: cardData)
                Divider()
            }

            if let modelCard = model.modelCard {
                descriptionSection(modelCard)
                Divider()
            }

            DiscoveryModelInfoSection(model: model)
            Divider()
            DiscoveryModelLicenseSection(model: model)
            actionButtons
        }
    }

    // MARK: - Sections

    private var imageGallerySection: some View {
        Group {
            let availableImageUrls: [URL] = buildImageUrls()
            if !availableImageUrls.isEmpty {
                Divider()
                DiscoveryModelDetailImageGallery(
                    imageUrls: availableImageUrls,
                    modelName: model.name
                )
                .onAppear {
                    logger.info("🖼️ Gallery: \(availableImageUrls.count) images")
                }
            } else {
                EmptyView()
                    .onAppear {
                        logger.info("🖼️ No images for '\(model.name)'")
                    }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text(model.name)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)

            HStack(spacing: DesignConstants.Spacing.medium) {
                if let modelType = model.inferredModelType {
                    Label(
                        displayName(for: modelType),
                        systemImage: iconName(for: modelType)
                    )
                } else {
                    Label(
                        "Unknown Type",
                        systemImage: "questionmark.circle"
                    )
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                }

                if !model.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignConstants.Spacing.small) {
                            ForEach(model.tags.prefix(DetailLayout.maxTags), id: \.self) { tag in
                                tagView(tag)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.caption)
            .foregroundColor(.accentColor)
            .padding(.horizontal, DesignConstants.Spacing.small)
            .padding(.vertical, DesignConstants.Spacing.xSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                    .fill(Color.accentColor.opacity(DetailLayout.tagBackgroundOpacity))
            )
    }

    private func descriptionSection(_ modelCard: String) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("Description", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(modelCard)
                .font(.body)
                .foregroundColor(.textPrimary)
                .lineLimit(showingFullDescription ? nil : DetailLayout.descriptionLineLimit)
                .animation(.default, value: showingFullDescription)

            if modelCard.count > DetailLayout.descriptionCharacterThreshold {
                Button {
                    showingFullDescription.toggle()
                } label: {
                    Text(
                        showingFullDescription
                            ? String(localized: "Show Less", bundle: .module)
                            : String(localized: "Show More", bundle: .module)
                    )
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.vertical, DesignConstants.Spacing.small)
                .background(
                    RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                        .fill(Color.backgroundPrimary)
                )
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            HStack {
                Spacer()
                ModelActionButton(discoveredModel: model)
                    .buttonStyle(.borderedProminent)
                Spacer()
            }

            Button {
                if let url = URL(string: "https://huggingface.co/\(model.id)") {
                    safariURL = url
                    showingSafariView = true
                }
            } label: {
                Label(
                    String(localized: "View on HuggingFace", bundle: .module),
                    systemImage: "safari"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, DesignConstants.Spacing.large)
    }

    // MARK: - Helper Methods

    private func buildImageUrls() -> [URL] {
        logger.info("🖼️ Building imageUrls for '\(model.name)'")
        var urls: [URL] = []

        // Add images from imageUrls array
        if !model.imageUrls.isEmpty {
            let validUrls: [URL] = model.imageUrls.compactMap(URL.init(string:))
            urls.append(contentsOf: validUrls)
        }

        // Add thumbnail from cardData if not already included
        if let thumbnail = model.cardData?.thumbnail,
            let thumbnailUrl = URL(string: thumbnail),
            !urls.contains(thumbnailUrl) {
            urls.append(thumbnailUrl)
        }

        logger.info("📊 Total: \(urls.count) images")
        return urls
    }

    private func navigateToMyModels() {
        #if os(macOS)
            // On macOS, close the Discovery window and focus on main window
            if let window = NSApplication.shared.keyWindow {
                window.close()
            }

            // Focus on the main window to show My Models
            let windowSearchDelay: TimeInterval = 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + windowSearchDelay) {
                if let mainWindow = NSApplication.shared.windows.first(where: { window in
                    !window.title.contains("Discover")
                }) {
                    mainWindow.makeKeyAndOrderFront(nil)

                    // Post notification to open My Models popover
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowMyModelsPopover"),
                        object: nil
                    )
                }
            }
        #else
            // On iOS, switch to My Models tab to show download progress
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToMyModels"),
                object: nil
            )
        #endif
    }

    private func displayName(for type: SendableModel.ModelType) -> String {
        switch type {
        case .language, .deepLanguage, .flexibleThinker:
            String(localized: "Language Model", bundle: .module)

        case .diffusion, .diffusionXL:
            String(localized: "Image Generation", bundle: .module)

        case .visualLanguage:
            String(localized: "Vision Language Model", bundle: .module)
        }
    }
}

// MARK: - Helper Functions

private func iconName(for type: SendableModel.ModelType) -> String {
    switch type {
    case .language, .deepLanguage, .flexibleThinker:
        "text.bubble"

    case .diffusion, .diffusionXL:
        "photo"

    case .visualLanguage:
        "eye"
    }
}

// MARK: - Constants

private enum DetailLayout {
    static let maxTags: Int = 5
    static let tagBackgroundOpacity: Double = 0.1
    static let descriptionLineLimit: Int = 5
    static let descriptionCharacterThreshold: Int = 200
    static let previewDownloads: Int = 100_000
    static let previewLikes: Int = 1_000
}

// MARK: - Preview

#if DEBUG
    #Preview {
        let model: DiscoveredModel = DiscoveredModel(
            id: "test-model",
            name: "Test Model",
            author: "test-author",
            downloads: DetailLayout.previewDownloads,
            likes: DetailLayout.previewLikes,
            tags: ["test"],
            lastModified: Date(),
            files: [],
            license: "Apache 2.0",
            licenseUrl: nil,
            metadata: [:]
        )

        let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: "Test description",
            cardData: nil,
            imageUrls: ["https://picsum.photos/600/400"],
            detectedBackends: [.mlx]
        )
        model.enrich(with: enrichedDetails)

        return DiscoveryModelDetailView(model: model)
    }
#endif
