import Abstractions
import Kingfisher
import OSLog
import SwiftUI

/// A compact card view for displaying discovered models in the carousel
internal struct DiscoveryModelCard: View {
    // MARK: - Properties

    let model: DiscoveredModel
    private let logger: Logger = .init(subsystem: "UIComponents", category: "DiscoveryModelCard")

    @State private var isHovered: Bool = false

    // MARK: - Initialization

    init(model: DiscoveredModel) {
        self.model = model
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Square image section at the top
            imageSection
                .frame(height: DiscoveryConstants.Card.imageSize.height)

            // Content section
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
                cardHeader
                Spacer()
                cardStats
                cardMetadata
            }
            .padding(DesignConstants.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DiscoveryConstants.Card.width, height: DiscoveryConstants.Card.height)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .fill(Color.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.marketingSecondary.opacity(DiscoveryConstants.Opacity.medium),
                            Color.marketingSecondary.opacity(DiscoveryConstants.Opacity.light)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignConstants.Line.thin
                )
        )
        .shadow(
            color: .black.opacity(DiscoveryConstants.Card.shadowOpacity),
            radius: DiscoveryConstants.Card.shadowRadius,
            x: 0,
            y: DiscoveryConstants.Card.shadowY
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .scaleEffect(isHovered ? DesignConstants.Scale.hover : DesignConstants.Scale.normal)
        .animation(
            .spring(
                response: DesignConstants.Animation.spring,
                dampingFraction: DesignConstants.Animation.springDamping
            ),
            value: isHovered
        )
        .onHover { hovering in
            #if os(macOS)
                withAnimation(.easeOut(duration: DesignConstants.Animation.standard)) {
                    isHovered = hovering
                }
            #endif
        }
    }

    // MARK: - Computed Properties

    private var imageSection: some View {
        Group {
            if !model.imageUrls.isEmpty,
                let firstUrl = model.imageUrls.first,
                let url = URL(string: firstUrl) {
                cardImage(url: url)
                    .onAppear {
                        logger.info("🖼️ Showing image from imageUrls: \(firstUrl)")
                    }
            } else if let thumbnail = model.cardData?.thumbnail,
                let url = URL(string: thumbnail) {
                cardImage(url: url)
                    .onAppear {
                        logger.info("🖼️ Showing image from cardData.thumbnail: \(thumbnail)")
                    }
            } else {
                // Architecture logo fallback
                ArchitectureLogoProvider.styledLogoView(for: model.name)
                    .transition(.opacity.combined(with: .scale(scale: DesignConstants.Scale.small)))
                    .onAppear {
                        logger.info("Showing architecture logo for '\(model.name)'")
                    }
            }
        }
    }

    // MARK: - Subviews

    private func cardImage(url: URL) -> some View {
        CachedAsyncImageView(
            url: url,
            targetSize: DiscoveryConstants.Card.imageSize,
            contentMode: .fill,
            enableProgressiveLoading: true
        ) {
            imagePlaceholder
        } errorView: {
            imageErrorView
        }
        .frame(
            width: DiscoveryConstants.Card.imageSize.width,
            height: DiscoveryConstants.Card.imageSize.height
        )
        .clipped()
        .clipShape(
            RoundedRectangle(cornerRadius: DesignConstants.Radius.standard, style: .continuous)
        )
        .overlay(imageOverlay)
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text(model.name)
                .font(.system(
                    size: DiscoveryConstants.FontSize.cardTitle,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundColor(.textPrimary)
                .lineLimit(DiscoveryConstants.Card.lineLimit)
                .multilineTextAlignment(.leading)
                .animation(
                    .easeOut(duration: DesignConstants.Animation.standard),
                    value: model.name
                )

            Text("by \(model.author)", bundle: .module)
                .font(.system(
                    size: DiscoveryConstants.FontSize.cardAuthor,
                    weight: .regular,
                    design: .rounded
                ))
                .foregroundColor(.textSecondary.opacity(DiscoveryConstants.Opacity.strong))
                .lineLimit(1)
        }
    }

    private var cardStats: some View {
        HStack(spacing: DesignConstants.Spacing.large) {
            statsView(
                icon: "arrow.down.circle.fill",
                value: formatNumber(model.downloads)
            )

            statsView(
                icon: "heart.fill",
                value: formatNumber(model.likes)
            )
        }
    }

    private var cardMetadata: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text(model.formattedTotalSize)
                .font(.system(
                    size: DiscoveryConstants.FontSize.cardBadge,
                    weight: .medium,
                    design: .rounded
                ))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignConstants.Spacing.medium)
                .padding(.vertical, DesignConstants.Spacing.small)
                .background(
                    Capsule()
                        .fill(
                            Color.backgroundPrimary
                                .opacity(DiscoveryConstants.Opacity.strong)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Color.textSecondary
                                        .opacity(DiscoveryConstants.Opacity.light),
                                    lineWidth: 1
                                )
                        )
                )

            if let backend = model.primaryBackend {
                backendIndicator(backend)
            }
        }
    }

    private func backendIndicator(_ backend: SendableModel.Backend) -> some View {
        Text(backend.displayName)
            .font(.system(
                size: DiscoveryConstants.FontSize.cardBadge,
                weight: .medium,
                design: .rounded
            ))
            .foregroundColor(.white)
            .padding(.horizontal, DesignConstants.Spacing.medium)
            .padding(.vertical, DesignConstants.Spacing.small)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.marketingSecondary,
                                Color.marketingSecondary
                                    .opacity(DiscoveryConstants.Opacity.strong)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(
                color: Color.marketingSecondary
                    .opacity(DiscoveryConstants.Opacity.medium),
                radius: DesignConstants.Shadow.radius,
                x: DesignConstants.Shadow.xAxis,
                y: DesignConstants.Shadow.yAxis
            )
    }
}

// MARK: - Backend Display Names

extension SendableModel.Backend {
    var displayName: String {
        switch self {
        case .mlx:
            "MLX"

        case .gguf:
            "GGUF"

        case .coreml:
            "Core ML"

        case .remote:
            "Remote"
        }
    }
}
