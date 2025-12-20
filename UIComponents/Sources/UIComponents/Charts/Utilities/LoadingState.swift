import SwiftUI

// MARK: - Loading State

/// Represents the loading state of dashboard data
public enum LoadingState<T> {
    /// Error state with associated error
    case error(Error)
    /// Initial idle state
    case idle
    /// Data successfully loaded
    case loaded(T)
    /// Currently loading with progress
    case loading(progress: Double)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var data: T? {
        if case let .loaded(data) = self {
            return data
        }
        return nil
    }

    var progress: Double {
        if case let .loading(progress) = self {
            return progress
        }
        return 0
    }
}

// MARK: - Constants

private enum LoadingConstants {
    static let spacing: CGFloat = 20
    static let progressSpacing: CGFloat = 12
    static let progressWidth: CGFloat = 200
    static let progressScale: CGFloat = 1.5
    static let padding: CGFloat = 40
    static let progressPercentMultiplier: Int = 100
}

// MARK: - Loading View

/// Reusable loading view for dashboards
public struct DashboardLoadingView: View {
    let message: String
    let progress: Double?

    public init(message: String = "Loading metrics...", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    public var body: some View {
        VStack(spacing: LoadingConstants.spacing) {
            if let progress {
                // Show determinate progress
                VStack(spacing: LoadingConstants.progressSpacing) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: LoadingConstants.progressWidth)

                    Text("\(Int(progress * Double(LoadingConstants.progressPercentMultiplier)))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show indeterminate progress
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(LoadingConstants.progressScale)
            }

            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LoadingConstants.padding)
    }
}

// MARK: - Skeleton Constants

private enum SkeletonConstants {
    static let spacing: CGFloat = 16
    static let titleWidth: CGFloat = 200
    static let titleHeight: CGFloat = 24
    static let titleCornerRadius: CGFloat = 4
    static let chartCornerRadius: CGFloat = 8
    static let chartHeight: CGFloat = 300
    static let legendSpacing: CGFloat = 20
    static let legendItemSpacing: CGFloat = 8
    static let legendCircleSize: CGFloat = 8
    static let legendRectWidth: CGFloat = 60
    static let legendRectHeight: CGFloat = 12
    static let legendRectCornerRadius: CGFloat = 2
    static let animationDuration: TimeInterval = 1.5
    static let shimmerWidthRatio: CGFloat = 0.3
    static let legendItemCount: Int = 3
    static let opacityLow: Double = 0.1
    static let opacityMedium: Double = 0.3
}

// MARK: - Skeleton View

/// Skeleton loading view for charts
public struct ChartSkeletonView: View {
    @State private var isAnimating: Bool = false

    private var titleSkeleton: some View {
        RoundedRectangle(cornerRadius: SkeletonConstants.titleCornerRadius)
            .fill(Color.gray.opacity(SkeletonConstants.opacityMedium))
            .frame(width: SkeletonConstants.titleWidth, height: SkeletonConstants.titleHeight)
    }

    private var legendSkeleton: some View {
        HStack(spacing: SkeletonConstants.legendSpacing) {
            ForEach(0 ..< SkeletonConstants.legendItemCount, id: \.self) { _ in
                HStack(spacing: SkeletonConstants.legendItemSpacing) {
                    Circle()
                        .fill(Color.gray.opacity(SkeletonConstants.opacityMedium))
                        .frame(
                            width: SkeletonConstants.legendCircleSize,
                            height: SkeletonConstants.legendCircleSize
                        )

                    RoundedRectangle(cornerRadius: SkeletonConstants.legendRectCornerRadius)
                        .fill(Color.gray.opacity(SkeletonConstants.opacityMedium))
                        .frame(
                            width: SkeletonConstants.legendRectWidth,
                            height: SkeletonConstants.legendRectHeight
                        )
                }
            }
        }
    }

    private var chartAreaSkeleton: some View {
        RoundedRectangle(cornerRadius: SkeletonConstants.chartCornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(SkeletonConstants.opacityMedium),
                        Color.gray.opacity(SkeletonConstants.opacityLow),
                        Color.gray.opacity(SkeletonConstants.opacityMedium)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: SkeletonConstants.chartHeight)
            .overlay(shimmerEffect)
    }

    private var shimmerEffect: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(SkeletonConstants.opacityMedium),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * SkeletonConstants.shimmerWidthRatio)
                .offset(
                    x: isAnimating ?
                        geometry.size.width :
                        -geometry.size.width * SkeletonConstants.shimmerWidthRatio
                )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SkeletonConstants.spacing) {
            titleSkeleton
            chartAreaSkeleton
            legendSkeleton
        }
        .padding()
        .onAppear {
            withAnimation(
                .linear(duration: SkeletonConstants.animationDuration)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}
