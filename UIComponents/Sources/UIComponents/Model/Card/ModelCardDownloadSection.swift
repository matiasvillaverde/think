import Database
import SwiftUI

/// Download progress section for ModelCard
internal struct ModelCardDownloadSection: View {
    @Bindable var model: Model
    let onPause: () -> Void
    let onResume: () -> Void
    @Binding var isCancelConfirmationPresented: Bool

    var body: some View {
        switch model.state {
        case .downloadingActive:
            HStack(spacing: DesignConstants.Spacing.large) {
                CompactProgressBar(
                    progress: model.downloadProgress ?? 0,
                    bytesDownloaded: Int64((model.downloadProgress ?? 0) * Double(model.size)),
                    totalBytes: Int64(model.size),
                    onTap: onPause
                )

                DownloadControlBar(
                    isActive: true,
                    onPause: onPause,
                    onResume: onResume
                ) {
                    isCancelConfirmationPresented = true
                }
            }

        case .downloadingPaused:
            HStack(spacing: DesignConstants.Spacing.large) {
                CompactProgressBar(
                    progress: model.downloadProgress ?? 0,
                    bytesDownloaded: Int64((model.downloadProgress ?? 0) * Double(model.size)),
                    totalBytes: Int64(model.size),
                    onTap: onResume
                )

                DownloadControlBar(
                    isActive: false,
                    onPause: onPause,
                    onResume: onResume
                ) {
                    isCancelConfirmationPresented = true
                }
            }

        default:
            EmptyView()
        }
    }
}
