import SwiftUI
import Testing
@testable import UIComponents

@Suite("DownloadProgressView Tests")
@MainActor
internal struct DownloadProgressViewTests {
    @Test("View displays progress information correctly")
    @MainActor
    func displaysProgressInformation() {
        let progress: Double = 0.35
        let bytesDownloaded: Int64 = 450_000_000
        let totalBytes: Int64 = 1_300_000_000
        let downloadSpeed: Double = 5_242_880 // 5 MB/s
        let timeRemaining: TimeInterval = 162 // 2:42

        let view: DownloadProgressView = DownloadProgressView(
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            downloadSpeed: downloadSpeed,
            estimatedTimeRemaining: timeRemaining
        )

        // View should compile and display the information
        #expect(view.progress == progress)
        #expect(view.bytesDownloaded == bytesDownloaded)
        #expect(view.totalBytes == totalBytes)
        #expect(view.downloadSpeed == downloadSpeed)
        #expect(view.estimatedTimeRemaining == timeRemaining)
    }

    @Test("View accepts optional onTap handler")
    @MainActor
    func acceptsOnTapHandler() {
        var tapCalled: Bool = false

        let view: DownloadProgressView = DownloadProgressView(
            progress: 0.5,
            bytesDownloaded: 500_000_000,
            totalBytes: 1_000_000_000,
            downloadSpeed: 1_000_000,
            estimatedTimeRemaining: 500
        ) {
            tapCalled = true
        }

        // View should compile with onTap parameter
        #expect(view.onTap != nil)
    }

    @Test("View remains passive when no onTap provided")
    @MainActor
    func remainsPassiveWithoutOnTap() {
        let view: DownloadProgressView = DownloadProgressView(
            progress: 0.5,
            bytesDownloaded: 500_000_000,
            totalBytes: 1_000_000_000,
            downloadSpeed: 1_000_000,
            estimatedTimeRemaining: 500
        )

        // View should compile without onTap parameter
        #expect(view.onTap == nil)
    }

    @Test("View handles edge cases gracefully")
    @MainActor
    func handlesEdgeCases() {
        // Zero progress
        let zeroProgress: DownloadProgressView = DownloadProgressView(
            progress: 0.0,
            bytesDownloaded: 0,
            totalBytes: 1_000_000_000
        )
        #expect(zeroProgress.progress == 0.0)

        // Complete progress
        let completeProgress: DownloadProgressView = DownloadProgressView(
            progress: 1.0,
            bytesDownloaded: 1_000_000_000,
            totalBytes: 1_000_000_000
        )
        #expect(completeProgress.progress == 1.0)

        // No speed or time info
        let noMetrics: DownloadProgressView = DownloadProgressView(
            progress: 0.5,
            bytesDownloaded: 500_000_000,
            totalBytes: 1_000_000_000,
            downloadSpeed: nil,
            estimatedTimeRemaining: nil
        )
        #expect(noMetrics.downloadSpeed == nil)
        #expect(noMetrics.estimatedTimeRemaining == nil)
    }
}
