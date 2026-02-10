import SwiftUI

/// Download progress view with animations and accurate time estimation
internal struct DownloadProgressView: View {
    internal let progress: Double
    internal let bytesDownloaded: Int64
    internal let totalBytes: Int64
    internal let downloadSpeed: Double?
    internal let estimatedTimeRemaining: TimeInterval?
    internal let onTap: (() -> Void)?

    // MARK: - Initialization

    internal init(
        progress: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        downloadSpeed: Double? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.downloadSpeed = downloadSpeed
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.onTap = onTap
    }

    @State private var isAnimating: Bool = false

    // MARK: - Layout Constants

    private enum Layout {
        static let circleSize: CGFloat = 120
        static let lineWidth: CGFloat = 8
        static let animationDuration: Double = 1.5
        static let spacing: CGFloat = 16
        static let iconSize: CGFloat = 48
        static let pauseIconSize: CGFloat = 40
        static let pauseIconOpacity: Double = 0.3
        static let pauseIconOffset: CGFloat = -5
        static let percentageMultiplier: Int = 100
        static let gradientOpacityMin: Double = 0
        static let gradientOpacityMid: Double = 0.3
        static let gradientScaleFactor: CGFloat = 1.1
        static let spacingSmall: CGFloat = 4
        static let spacingMedium: CGFloat = 8
        static let previewSpacing: CGFloat = 40
        static let rotationAngle: Double = -90
        static let fullRotation: Double = 360
        static let progressMin: CGFloat = 0
        static let progressMax: CGFloat = 1.0
        static let lineWidthMultiplier: Double = 0.5
        static let maxUnitCount: Int = 2
        static let downloadBytesExample1: Int64 = 450_000_000
        static let totalBytesExample1: Int64 = 1_300_000_000
        static let downloadSpeedExample1: Double = 5_242_880 // 5 MB/s
        static let timeRemainingExample1: Double = 162 // 2:42
        static let progressExample1: Double = 0.35
        static let downloadBytesExample2: Int64 = 1_105_000_000
        static let totalBytesExample2: Int64 = 1_300_000_000
        static let downloadSpeedExample2: Double = 10_485_760 // 10 MB/s
        static let timeRemainingExample2: Double = 19
        static let progressExample2: Double = 0.85
    }

    internal var body: some View {
        if let onTap {
            Button(action: onTap) {
                contentView
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(spacing: Layout.spacing) {
            progressCircle
            statsView
        }
        .onAppear {
            withAnimation(
                .linear(duration: Layout.animationDuration)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }

    private var progressCircle: some View {
        ZStack {
            backgroundCircle
            progressArc
            centerContent
            animatedRing
        }
        .frame(width: Layout.circleSize, height: Layout.circleSize)
    }

    private var backgroundCircle: some View {
        Circle()
            .stroke(
                Color.backgroundSecondary,
                lineWidth: Layout.lineWidth
            )
    }

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                Color.accentColor,
                style: StrokeStyle(
                    lineWidth: Layout.lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(Layout.rotationAngle))
            .animation(.smooth, value: progress)
    }

    private var centerContent: some View {
        VStack(spacing: Layout.spacingSmall) {
            Text(verbatim: "\(Int(progress * Double(Layout.percentageMultiplier)))%")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)

            if let speed = formattedSpeed {
                Text(speed)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }

    @ViewBuilder private var animatedRing: some View {
        if progress < Layout.progressMax {
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(Layout.gradientOpacityMin),
                            Color.accentColor.opacity(Layout.gradientOpacityMid),
                            Color.accentColor.opacity(Layout.gradientOpacityMin)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: Layout.lineWidth * Layout.lineWidthMultiplier
                )
                .rotationEffect(.degrees(isAnimating ? Layout.fullRotation : 0))
                .scaleEffect(Layout.gradientScaleFactor)
        }
    }

    private var statsView: some View {
        VStack(spacing: Layout.spacingMedium) {
            // Downloaded / Total
            HStack {
                Text(formattedBytes(bytesDownloaded))
                    .foregroundColor(.textPrimary)
                Text("/")
                    .foregroundColor(.textSecondary)
                Text(formattedBytes(totalBytes))
                    .foregroundColor(.textSecondary)
            }
            .font(.subheadline)

            // Time remaining
            if let timeRemaining = estimatedTimeRemaining,
                timeRemaining.isFinite,
                timeRemaining > 0 {
                Text(formattedTimeRemaining(timeRemaining))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            // Tap hint when interactive
            if onTap != nil {
                pauseView
            }
        }
    }

    private var pauseView: some View {
        HStack {
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundColor(Color.iconPrimary.opacity(Layout.pauseIconOpacity))
            Text("tap to pause", bundle: .module)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }.accessibilityLabel(
            String(
                localized: "Pause download",
                bundle: .module,
                comment: "Accessibility label for pause icon"
            )
        )
    }

    // MARK: - Formatting Helpers

    private var formattedSpeed: String? {
        guard let speed = downloadSpeed, speed > 0 else {
            return nil
        }
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedTimeRemaining(_ seconds: TimeInterval) -> String {
        let formatter: DateComponentsFormatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = Layout.maxUnitCount

        if let formatted = formatter.string(from: seconds) {
            return String(localized: "\(formatted) remaining", bundle: .module)
        }
        return ""
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 40) {
            // Passive version (no tap action)
            DownloadProgressView(
                progress: 0.35,
                bytesDownloaded: 450_000_000,
                totalBytes: 1_300_000_000,
                downloadSpeed: 5_242_880,
                estimatedTimeRemaining: 162
            )

            // Interactive version (with tap action)
            DownloadProgressView(
                progress: 0.85,
                bytesDownloaded: 1_105_000_000,
                totalBytes: 1_300_000_000,
                downloadSpeed: 10_485_760,
                estimatedTimeRemaining: 19
            ) {
                // no-op
            }
        }
        .padding()
    }
#endif
