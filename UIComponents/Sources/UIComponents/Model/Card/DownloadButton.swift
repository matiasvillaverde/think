import Abstractions
import Database
import SwiftUI

internal struct DownloadButton: View {
    @Bindable var model: Model

    @Binding var isConfirmationPresented: Bool

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(model.size),
            countStyle: .file
        )
    }

    var body: some View {
        VStack {
            downloadButton
            sizeLabel
        }
    }

    private var downloadButton: some View {
        Button(action: showConfirmation) {
            VStack(spacing: DesignConstants.Spacing.small) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: DesignConstants.Size.iconSmall))
                    .foregroundColor(Color.iconConfirmation)
                    .accessibilityLabel(
                        String(
                            localized: "Download model",
                            bundle: .module,
                            comment: "Accessibility label for the download button"
                        )
                    )
                Text("Download", bundle: .module)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(Color.iconConfirmation)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var sizeLabel: some View {
        Text(formattedSize)
            .font(.caption2)
            .foregroundColor(Color.textSecondary)
            .accessibilityLabel(
                String(
                    localized: "File size \(formattedSize)",
                    bundle: .module,
                    comment: "Accessibility label for the download button"
                )
            )
    }

    private func showConfirmation() {
        isConfirmationPresented = true
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var model: Model = .preview
        @Previewable @State var toggle: Bool = false
        DownloadButton(model: model, isConfirmationPresented: $toggle)
    }
#endif
