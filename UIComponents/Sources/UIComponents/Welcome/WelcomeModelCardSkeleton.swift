import SkeletonUI
import SwiftUI

internal struct WelcomeModelCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WelcomeConstants.spacingSmall) {
            headerSkeleton
            statsSkeleton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: WelcomeConstants.cornerRadius)
                .fill(Color.backgroundSecondary)
        )
    }

    @ViewBuilder private var headerSkeleton: some View {
        HStack {
            Circle()
                .fill(Color.paletteGray.opacity(WelcomeConstants.skeletonOpacity))
                .frame(
                    width: WelcomeConstants.skeletonCircleSize,
                    height: WelcomeConstants.skeletonCircleSize
                )
                .skeleton(with: true)

            VStack(alignment: .leading, spacing: WelcomeConstants.spacingTiny) {
                RoundedRectangle(cornerRadius: WelcomeConstants.skeletonCornerRadius)
                    .fill(Color.paletteGray.opacity(WelcomeConstants.skeletonOpacity))
                    .frame(
                        width: WelcomeConstants.skeletonTitleWidth,
                        height: WelcomeConstants.skeletonTitleHeight
                    )
                    .skeleton(with: true)

                RoundedRectangle(cornerRadius: WelcomeConstants.skeletonCornerRadius)
                    .fill(Color.paletteGray.opacity(WelcomeConstants.skeletonOpacity))
                    .frame(
                        width: WelcomeConstants.skeletonSubtitleWidth,
                        height: WelcomeConstants.skeletonSubtitleHeight
                    )
                    .skeleton(with: true)
            }

            Spacer()
        }
    }

    @ViewBuilder private var statsSkeleton: some View {
        HStack(spacing: WelcomeConstants.spacingMedium) {
            ForEach(0 ..< WelcomeConstants.capabilityLimit, id: \.self) { _ in
                RoundedRectangle(cornerRadius: WelcomeConstants.skeletonCornerRadius)
                    .fill(Color.paletteGray.opacity(WelcomeConstants.skeletonOpacity))
                    .frame(
                        width: WelcomeConstants.skeletonStatWidth,
                        height: WelcomeConstants.skeletonStatHeight
                    )
                    .skeleton(with: true)
            }

            Spacer()
        }
    }
}
