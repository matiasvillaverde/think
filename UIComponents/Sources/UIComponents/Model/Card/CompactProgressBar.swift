import SwiftUI

/// A compact horizontal progress bar for download indicators
internal struct CompactProgressBar: View {
    private enum Constants {
        static let spacing: CGFloat = 4
        static let progressHeight: CGFloat = 6
        static let scaleY: CGFloat = 1.5
        static let scaleX: CGFloat = 1
        static let percentMultiplier: Int = 100
    }

    let progress: Double
    let downloadedSize: String
    let totalSize: String
    let onTap: (() -> Void)?

    // MARK: - Initialization

    init(
        progress: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        onTap: (() -> Void)? = nil
    ) {
        self.progress = progress
        downloadedSize = ByteCountFormatter.string(
            fromByteCount: bytesDownloaded,
            countStyle: .file
        )
        totalSize = ByteCountFormatter.string(
            fromByteCount: totalBytes,
            countStyle: .file
        )
        self.onTap = onTap
    }

    var body: some View {
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
        VStack(spacing: Constants.spacing) {
            ProgressView(value: progress)
                .tint(.accentColor)
                .scaleEffect(
                    x: Constants.scaleX,
                    y: Constants.scaleY,
                    anchor: .center
                )
                .frame(height: Constants.progressHeight)

            HStack {
                Text(downloadedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(progress * Double(Constants.percentMultiplier)))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(totalSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            makeAccessibilityLabel()
        )
        .accessibilityHint(
            onTap != nil ? String(
                localized: "Tap to pause or resume",
                bundle: .module
            ) : ""
        )
    }

    private func makeAccessibilityLabel() -> String {
        let percentage: Int = Int(progress * Double(Constants.percentMultiplier))
        return String(
            localized: "Download progress \(percentage)%, \(downloadedSize) of \(totalSize)",
            bundle: .module
        )
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Compact Progress Bar") {
        VStack(spacing: 20) {
            CompactProgressBar(
                progress: 0.25,
                bytesDownloaded: 250_000_000,
                totalBytes: 1_000_000_000
            )

            CompactProgressBar(
                progress: 0.75,
                bytesDownloaded: 750_000_000,
                totalBytes: 1_000_000_000
            ) {
            }
        }
        .padding()
    }
#endif
