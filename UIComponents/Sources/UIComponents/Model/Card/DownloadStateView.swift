import Abstractions
import Database
import SwiftUI

/// A view that displays the appropriate download state UI based on the model's current state
internal struct DownloadStateView: View {
    // MARK: - Properties

    @Bindable var model: Model
    @Binding var isConfirmationPresented: Bool
    @Binding var isDeleteConfirmationPresented: Bool
    @Binding var isCancelConfirmationPresented: Bool
    let isSelected: Bool

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    // MARK: - Body

    internal var body: some View {
        switch model.state {
        case .downloadingActive:
            CompactProgressBar(
                progress: model.downloadProgress ?? 0,
                bytesDownloaded: Int64((model.downloadProgress ?? 0) * Double(model.size)),
                totalBytes: Int64(model.size),
                onTap: handlePauseDownload
            )

        case .downloadingPaused:
            // Use CompactProgressBar in paused state with resume action
            CompactProgressBar(
                progress: model.downloadProgress ?? 0,
                bytesDownloaded: Int64((model.downloadProgress ?? 0) * Double(model.size)),
                totalBytes: Int64(model.size),
                onTap: handleResumeDownload
            )

        case .notDownloaded:
            DownloadButton(
                model: model,
                isConfirmationPresented: $isConfirmationPresented
            )

        case .downloaded:
            // Check runtime state for actual status
            switch model.runtimeState {
            case .error:
                StateIndicator(
                    icon: "exclamationmark.circle.fill",
                    text: "Error",
                    color: Color.iconAlert
                )

            case .loading:
                // Show loading progress
                StateIndicator(
                    icon: "progress.indicator",
                    text: "Loading",
                    color: Color.accentColor
                )

            case .generating:
                // Show generating status
                StateIndicator(
                    icon: "brain.filled.head.profile",
                    text: "Generating",
                    color: Color.paletteGreen
                )

            case .loaded, .notLoaded:
                // Show delete button when downloaded but not selected
                if !isSelected {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                            Text("Delete", bundle: .module)
                        }
                    }
                    .buttonStyle(.borderless)
                } else {
                    EmptyView()
                }

            case .none:
                // Default case for optional runtimeState
                if !isSelected {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                            Text("Delete", bundle: .module)
                        }
                    }
                    .buttonStyle(.borderless)
                } else {
                    EmptyView()
                }
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Private Methods

    private func handlePauseDownload() {
        Task(priority: .userInitiated) {
            await modelActions.pauseDownload(modelId: model.id)
        }
    }

    private func handleResumeDownload() {
        Task(priority: .userInitiated) {
            await modelActions.resumeDownload(modelId: model.id)
        }
    }
}

// MARK: - Previews

#if DEBUG

    private enum PreviewConstants {
        static let downloadProgress25: Double = 0.25
        static let downloadProgress50: Double = 0.5
        static let downloadProgress75: Double = 0.75

        static let totalBytes: Int64 = 1_000_000_000
        static let bytesProgress25: Int64 = 250_000_000
        static let bytesProgress50: Int64 = 500_000_000
        static let bytesProgress75: Int64 = 750_000_000
    }

    #Preview("Download States") {
        @Previewable @State var models: [Model] = Model.previews
        List(models.prefix(5)) { model in
            VStack(alignment: .leading, spacing: 8) {
                Text(model.displayName)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                DownloadStateView(
                    model: model,
                    isConfirmationPresented: .constant(false),
                    isDeleteConfirmationPresented: .constant(false),
                    isCancelConfirmationPresented: .constant(false),
                    isSelected: false
                )
            }
            .padding(.vertical, 4)
        }
    }

    #Preview("All Download Button States") {
        ScrollView {
            VStack(spacing: 20) {
                notDownloadedPreview
                downloadingPreviews
                pausedPreview
                downloadedPreview
                errorPreview
            }
            .padding()
        }
    }

    @MainActor private var notDownloadedPreview: some View {
        VStack {
            Text(verbatim: "Not Downloaded")
                .font(.headline)
            DownloadButton(
                model: Model.preview,
                isConfirmationPresented: .constant(false)
            )
        }
    }

    @MainActor private var downloadingPreviews: some View {
        Group {
            VStack {
                Text(verbatim: "Downloading (25%)")
                    .font(.headline)
                CompactProgressBar(
                    progress: PreviewConstants.downloadProgress25,
                    bytesDownloaded: PreviewConstants.bytesProgress25,
                    totalBytes: PreviewConstants.totalBytes
                ) {
                    // no-op
                }
            }

            VStack {
                Text(verbatim: "Downloading (75%)")
                    .font(.headline)
                CompactProgressBar(
                    progress: PreviewConstants.downloadProgress75,
                    bytesDownloaded: PreviewConstants.bytesProgress75,
                    totalBytes: PreviewConstants.totalBytes
                ) {
                    // no-op
                }
            }
        }
    }

    @MainActor private var pausedPreview: some View {
        VStack {
            Text(verbatim: "Paused (50%)")
                .font(.headline)
            CompactProgressBar(
                progress: PreviewConstants.downloadProgress50,
                bytesDownloaded: PreviewConstants.bytesProgress50,
                totalBytes: PreviewConstants.totalBytes
            ) {
                // no-op
            }
        }
    }

    @MainActor private var downloadedPreview: some View {
        VStack {
            Text(verbatim: "Downloaded")
                .font(.headline)
            Button(role: .destructive) {
                // no-op
            } label: {
                Label {
                    Text(verbatim: "Delete")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var errorPreview: some View {
        VStack {
            Text(verbatim: "Error State")
                .font(.headline)
            StateIndicator(
                icon: "exclamationmark.circle.fill",
                text: String(localized: "Download failed", bundle: .module),
                color: Color.iconAlert
            )
        }
    }

#endif
