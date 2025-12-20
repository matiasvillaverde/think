import Abstractions
import Database
import SwiftUI
import UniformTypeIdentifiers

internal struct AttachmentButton: View {
    // MARK: - State

    @State private var isShowingFileImporter: Bool = false

    // MARK: - Environment

    @Environment(\.attacher)
    var viewModel: ViewModelAttaching

    @Bindable var chat: Chat

    // MARK: - Constants

    private enum Constants {
        static let maxFrameWidth: CGFloat = 20
        static let iconSize: CGFloat = 24
        static let taskPriority: TaskPriority = .userInitiated
    }

    // MARK: - Computed Properties

    var allowedTypes: [UTType] {
        [
            .pdf,
            .plainText,
            .json,
            .commaSeparatedText
        ]
    }

    // MARK: - Body

    var body: some View {
        Menu {
            Button {
                isShowingFileImporter.toggle()
            } label: {
                Label(
                    String(
                        localized: "Attach File",
                        bundle: .module,
                        comment: "Label for the button that allows the user to attach a file"
                    ),
                    systemImage: "folder"
                )
            }
        } label: {
            Label(
                String(
                    localized: "Attachment",
                    bundle: .module,
                    comment: "Label for the button that allows the user to attach a file"
                ),
                systemImage: "paperclip"
            )
            .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .foregroundStyle(Color.iconPrimary)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(files):
                if let file = files.first {
                    handleSelectedFile(file)
                }

            case let .failure(error):
                handleError(error)
            }
        }
        .frame(maxWidth: Constants.maxFrameWidth)
        .help(
            String(
                localized: "Attach a file to increase the knowledge of the AI",
                bundle: .module,
                comment: "Tooltip for the button that allows the user to attach a file"
            )
        )
    }

    // MARK: - Private Methods

    private func handleSelectedFile(_ file: URL) {
        // Start accessing the security-scoped resource
        guard file.startAccessingSecurityScopedResource() else {
            handleError(FileImporterError.accessDenied)
            return
        }

        defer {
            file.stopAccessingSecurityScopedResource()
        }

        Task(priority: Constants.taskPriority) {
            await viewModel.process(file: file, chatId: chat.id)
        }
    }

    private func handleError(_ error: Error) {
        Task(priority: Constants.taskPriority) {
            await viewModel.show(error: error)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview {
        AttachmentButton(chat: .preview)
            .environment(\.attacher, PreviewViewModelAttacher())
    }
#endif
