import SwiftUI

/// A control bar that displays appropriate download control buttons based on download state
internal struct DownloadControlBar: View {
    let isActive: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DesignConstants.Spacing.medium) {
            if isActive {
                PauseButton(action: onPause)
            } else {
                ResumeButton(action: onResume)
                CancelDownloadButton(action: onCancel)
            }
        }
    }
}
