import Abstractions
import Database
import SwiftUI

/// A view that displays a file attachment with its current processing state and information
internal struct FileAttachmentView: View {
    @Environment(\.attacher)
    var viewModel: ViewModelAttaching

    // MARK: - Properties

    @Bindable var file: FileAttachment

    // MARK: - Constants

    private enum Constants {
        static let maxWidth: CGFloat = 200
        static let cornerRadius: CGFloat = 12
        static let verticalPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 12
        static let iconSize: CGFloat = 48
        static let spacing: CGFloat = 12
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: Double = 0.4
        static let shadowOffsetY: CGFloat = 2
        static let deleteButtonSize: CGFloat = 12
        static let deleteButtonPadding: CGFloat = 6
        static let deleteButtonOpacity: Double = 0.6
        static let statusIconSize: CGFloat = 24
        static let lineLimit: Int = 2
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: Constants.spacing) {
                // Show either statusView or fileIconView based on ragState
                if file.ragState == .saved {
                    fileIconView
                } else {
                    statusView
                }

                fileInfoView
                Spacer()
            }
            .frame(maxWidth: Constants.maxWidth)
            .padding(.vertical, Constants.verticalPadding)
            .padding(.horizontal, Constants.horizontalPadding)

            if file.ragState != .saving {
                deleteButton
            }
        }
        .background(backgroundView)
        .help(
            String(
                localized: "File that is attached to the chat for searching",
                bundle: .module,
                comment: "Help text for FileAttachmentView"
            )
        )
    }

    // MARK: - Actions

    /// Initiates deletion of the file attachment
    private func deleteFile() {
        let id: UUID = file.id
        Task(priority: .userInitiated) {
            await viewModel.delete(file: id)
        }
    }

    // MARK: - Component Views

    /// View for the file icon based on the file type
    private var fileIconView: some View {
        Image(systemName: fileIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .foregroundStyle(Color.iconConfirmation)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(fileIcon)
    }

    /// View displaying file information (name and type)
    private var fileInfoView: some View {
        VStack {
            Text(file.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(Constants.lineLimit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textPrimary)

            Text(file.type.uppercased())
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(Constants.lineLimit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textPrimary)
        }
    }

    /// View displaying the current status of the file attachment
    @ViewBuilder private var statusView: some View {
        Group {
            switch file.ragState {
            case .saving:
                CircularProgressView(progress: file.progress, shouldAnimate: true)
                    .progressViewStyle(.circular)
                    .frame(width: Constants.statusIconSize, height: Constants.statusIconSize)
                    .tint(Color.marketingPrimary)

            case .saved:
                Label(
                    String(
                        localized: "Saved",
                        bundle: .module,
                        comment: "Status text for a saved file attachment"
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.iconConfirmation)
                .font(.system(size: Constants.statusIconSize))

            case .failed:
                failedStatusView

            case .notStarted:
                notStartedStatusView
            }
        }
    }

    private var failedStatusView: some View {
        Label(
            String(
                localized: "Failed",
                bundle: .module,
                comment: "Status text for a failed file attachment"
            ),
            systemImage: "exclamationmark.triangle.fill"
        )
        .labelStyle(.iconOnly)
        .foregroundStyle(Color.iconAlert)
        .font(.system(size: Constants.statusIconSize))
    }

    private var notStartedStatusView: some View {
        Label(
            String(
                localized: "Not Started",
                bundle: .module,
                comment: "Status text for a file attachment that hasn't started saving yet"
            ),
            systemImage: "circle.dotted"
        )
        .labelStyle(.iconOnly)
        .foregroundStyle(Color.textSecondary)
        .font(.system(size: Constants.statusIconSize))
    }

    /// Button for deleting the file attachment
    private var deleteButton: some View {
        Button(action: deleteFile) {
            Image(systemName: "xmark")
                .font(.system(size: Constants.deleteButtonSize, weight: .medium))
                .foregroundStyle(Color.iconPrimary)
                .contentShape(Rectangle())
                .accessibilityLabel(
                    String(
                        localized: "Delete file",
                        bundle: .module,
                        comment: "Accessibility label for the button to delete a file attachment"
                    )
                )
        }
        .buttonStyle(.plain)
        .opacity(Constants.deleteButtonOpacity)
        .padding(Constants.deleteButtonPadding)
        .help(
            String(
                localized: "Delete this attached file",
                bundle: .module,
                comment: "Tooltip text for the button to delete a file attachment"
            )
        )
    }

    /// Background view with rounded corners and shadow
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.backgroundPrimary)
            .shadow(
                color: Color.paletteBlack.opacity(Constants.shadowOpacity),
                radius: Constants.shadowRadius,
                x: 0,
                y: Constants.shadowOffsetY
            )
    }

    // MARK: - Helper Properties

    /// Returns the appropriate SF Symbol name for the file type
    private var fileIcon: String {
        switch file.type.lowercased() {
        case "pdf":
            "doc.text.fill"

        case "jpg", "jpeg", "png", "heic":
            "photo.fill"

        case "doc", "docx":
            "doc.fill"

        case "xls", "xlsx":
            "tablecells.fill"

        case "txt":
            "doc.plaintext.fill"

        case "zip", "rar":
            "doc.zipper"

        default:
            "doc.fill"
        }
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var files: [FileAttachment] = FileAttachment.previewsAllStates
        List(files) { file in
            FileAttachmentView(file: file)
        }
    }
#endif
