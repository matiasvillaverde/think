import SwiftUI

// MARK: - Skeleton Loading Views

internal struct RecommendedModelsSectionSkeleton: View {
    private enum Constants {
        static let numberOfCards: Int = 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            // Section header - always visible with hardcoded text
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.marketingSecondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading) {
                        Text("Recommended for You", bundle: .module)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.textPrimary)

                        Text("Models compatible with your device", bundle: .module)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)

            // Horizontal carousel skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignConstants.Spacing.large) {
                    ForEach(0 ..< Constants.numberOfCards, id: \.self) { index in
                        ModelCardSkeleton(index: index)
                    }
                }
                .padding(.horizontal, DesignConstants.Spacing.large)
            }
        }
    }
}

internal struct CommunityModelsSectionSkeleton: View {
    private enum Constants {
        static let numberOfCommunities: Int = 2
        static let numberOfCards: Int = 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.huge) {
            // Show skeletons for 2 communities
            ForEach(0 ..< Constants.numberOfCommunities, id: \.self) { communityIndex in
                communitySkeleton(communityIndex: communityIndex)
            }
        }
    }

    private func communitySkeleton(communityIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            // Community header - always visible with hardcoded text
            HStack {
                Image(systemName: communityIndex == 0 ? "cpu" : "square.stack.3d.up")
                    .font(.title2)
                    .foregroundColor(.marketingSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(communityIndex == 0 ? "MLX Community" : "Core ML Community")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.textPrimary)

                    Text(communityIndex == 0 ?
                        "Community models optimized for Apple Silicon using MLX framework" :
                        "Models optimized for Apple's Core ML framework")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, DesignConstants.Spacing.large)

            // Horizontal carousel skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignConstants.Spacing.large) {
                    ForEach(0 ..< Constants.numberOfCards, id: \.self) { cardIndex in
                        ModelCardSkeleton(
                            index: communityIndex * Constants.numberOfCards + cardIndex
                        )
                    }
                }
                .padding(.horizontal, DesignConstants.Spacing.large)
            }
        }
    }
}

internal struct ModelCardSkeleton: View {
    private enum Constants {
        static let titleWidth: CGFloat = 180
        static let titleHeight: CGFloat = 20
        static let authorWidth: CGFloat = 120
        static let authorHeight: CGFloat = 16
        static let iconSize: CGFloat = 16
        static let downloadTextWidth: CGFloat = 40
        static let likesTextWidth: CGFloat = 30
        static let textHeight: CGFloat = 16
        static let sizeWidth: CGFloat = 60
        static let backendWidth: CGFloat = 40
        static let metadataHeight: CGFloat = 20
        static let imageSkeletonHeight: CGFloat = 140
        static let cornerRadius: CGFloat = 6
        static let shimmerDuration: Double = 1.5
        static let shimmerOffset: CGFloat = 1.0
        static let primaryOpacity: Double = 0.08
        static let secondaryOpacity: Double = 0.15
        static let gradientStartOffset: CGFloat = -0.3
        static let gradientEndOffset: CGFloat = 0.3
        static let gradientY: CGFloat = 0.5
        static let animationDelay: Double = 0.1
        static let animationDuration: Double = 0.3
        static let scaleEffect: CGFloat = 0.95
        static let divisionFactor: CGFloat = 2
    }

    let index: Int
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var isVisible: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Square image skeleton section at the top
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(shimmerGradient)
                .frame(height: Constants.imageSkeletonHeight)

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
                    Color.marketingSecondary.opacity(DiscoveryConstants.Opacity.light),
                    lineWidth: DesignConstants.Line.thin
                )
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : Constants.scaleEffect)
        .animation(
            .easeOut(duration: Constants.animationDuration)
                .delay(Constants.animationDelay * Double(index)),
            value: isVisible
        )
        .onAppear {
            isVisible = true
            withAnimation(
                .linear(duration: Constants.shimmerDuration)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = Constants.shimmerOffset
            }
        }
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            // Model name skeleton
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(shimmerGradient)
                .frame(width: Constants.titleWidth, height: Constants.titleHeight)

            // Author skeleton
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(shimmerGradient)
                .frame(width: Constants.authorWidth, height: Constants.authorHeight)
        }
    }

    private var cardStats: some View {
        HStack(spacing: DesignConstants.Spacing.large) {
            HStack(spacing: DesignConstants.Spacing.small) {
                // Download icon skeleton
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(shimmerGradient)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)

                // Download count skeleton
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(shimmerGradient)
                    .frame(width: Constants.downloadTextWidth, height: Constants.textHeight)
            }

            HStack(spacing: DesignConstants.Spacing.small) {
                // Heart icon skeleton
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(shimmerGradient)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)

                // Likes count skeleton
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(shimmerGradient)
                    .frame(width: Constants.likesTextWidth, height: Constants.textHeight)
            }
        }
    }

    private var cardMetadata: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            // Size badge skeleton
            RoundedRectangle(cornerRadius: Constants.metadataHeight / Constants.divisionFactor)
                .fill(shimmerGradient)
                .frame(width: Constants.sizeWidth, height: Constants.metadataHeight)

            // Backend badge skeleton
            RoundedRectangle(cornerRadius: Constants.metadataHeight / Constants.divisionFactor)
                .fill(shimmerGradient)
                .frame(width: Constants.backendWidth, height: Constants.metadataHeight)
        }
    }

    private var shimmerGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.paletteGray.opacity(Constants.primaryOpacity),
                Color.paletteGray.opacity(Constants.secondaryOpacity),
                Color.paletteGray.opacity(Constants.primaryOpacity)
            ],
            startPoint: .init(
                x: shimmerOffset + Constants.gradientStartOffset,
                y: Constants.gradientY
            ),
            endPoint: .init(
                x: shimmerOffset + Constants.gradientEndOffset,
                y: Constants.gradientY
            )
        )
    }
}
