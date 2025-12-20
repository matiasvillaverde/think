import Abstractions
import Database
import SwiftUI

// MARK: - ModelActionButtonDownloadViews

/// Download-specific views and functionality for ModelActionButton
@MainActor
internal struct ModelActionButtonDownloadViews: View {
    // MARK: - Properties

    let progress: Double
    let sizeInBytes: UInt64
    let downloadSpeed: Double?
    let estimatedTimeRemaining: TimeInterval?
    let isActive: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        if isActive {
            activeDownloadView
        } else {
            pausedDownloadView
        }
    }

    // MARK: - Active Download View

    private var activeDownloadView: some View {
        DownloadProgressView(
            progress: progress,
            bytesDownloaded: Int64(progress * Double(sizeInBytes)),
            totalBytes: Int64(sizeInBytes),
            downloadSpeed: downloadSpeed,
            estimatedTimeRemaining: estimatedTimeRemaining,
            onTap: onPause
        )
    }

    // MARK: - Paused Download View

    private var pausedDownloadView: some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            DownloadProgressView(
                progress: progress,
                bytesDownloaded: Int64(progress * Double(sizeInBytes)),
                totalBytes: Int64(sizeInBytes),
                downloadSpeed: nil, // No speed when paused
                estimatedTimeRemaining: nil // No time estimate when paused
            )

            // Action buttons
            HStack(spacing: DesignConstants.Spacing.medium) {
                ResumeButton(action: onResume)
                CancelDownloadButton(action: onCancel)
            }
        }
    }
}

// MARK: - Download Metrics Helper

/// Helper class to track download metrics
@MainActor
internal final class DownloadMetricsTracker: ObservableObject {
    @Published var downloadSpeed: Double?
    @Published var estimatedTimeRemaining: TimeInterval?

    private var lastProgressUpdate: (progress: Double, date: Date)?

    func updateMetrics(newProgress: Double, modelSize: UInt64) {
        guard let lastUpdate = lastProgressUpdate else {
            lastProgressUpdate = (newProgress, Date())
            return
        }

        let now: Date = Date()
        let timeElapsed: TimeInterval = now.timeIntervalSince(lastUpdate.date)

        guard timeElapsed > 0 else {
            return
        }

        let progressChange: Double = newProgress - lastUpdate.progress
        let speed: Double = progressChange / timeElapsed

        if speed > 0 {
            downloadSpeed = speed * Double(modelSize)
            let remainingProgress: Double = 1.0 - newProgress
            estimatedTimeRemaining = remainingProgress / speed
        }

        lastProgressUpdate = (newProgress, now)
    }

    func reset() {
        downloadSpeed = nil
        estimatedTimeRemaining = nil
        lastProgressUpdate = nil
    }

    deinit {
        // Required by SwiftLint
    }
}

// MARK: - Loading View Extension

internal struct ModelActionButtonLoadingView: View {
    let progress: Double
    let sizeInBytes: UInt64

    var body: some View {
        DownloadProgressView(
            progress: progress,
            bytesDownloaded: Int64(progress * Double(sizeInBytes)),
            totalBytes: Int64(sizeInBytes),
            downloadSpeed: nil,
            estimatedTimeRemaining: nil
        )
    }
}
