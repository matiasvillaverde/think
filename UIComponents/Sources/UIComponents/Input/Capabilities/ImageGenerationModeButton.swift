import Abstractions
import Database
import SwiftUI
#if os(iOS)
    import UIKit
#endif

internal struct ImageGenerationModeButton: View {
    @Bindable var chat: Chat
    @Binding var selectedAction: Action

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @State private var showingConfirmation: Bool = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            Image(systemName: "photo")
                .font(.system(size: ToolConstants.toolsButtonIconSize, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .accessibilityLabel(String(
                    localized: "Create Image",
                    bundle: .module,
                    comment: "Button to switch to image generation"
                ))
        }
        .buttonStyle(.plain)
        .frame(width: ToolConstants.toolsButtonSize, height: ToolConstants.toolsButtonSize)
        .confirmationDialog(
            Text(String(
                localized: "Download Confirmation",
                bundle: .module,
                comment: "Title for the confirmation dialog when downloading image model"
            )),
            isPresented: $showingConfirmation,
            titleVisibility: .automatic
        ) {
            Button(
                String(
                    localized: "Download \(formattedSize(for: chat.imageModel)) Now",
                    bundle: .module,
                    comment: "Button confirmation to download the model data"
                ),
                role: .none
            ) {
                downloadAndSwitch()
            }

            Button(
                String(localized: "Cancel", bundle: .module),
                role: .cancel
            ) {
                showingConfirmation = false
            }
        } message: {
            Text(String(
                localized: """
                To create images, the image model needs to be downloaded from the internet. \
                This will require \(formattedSize(for: chat.imageModel)) of data. \
                Please confirm to proceed.
                """,
                bundle: .module,
                comment: "Message for the confirmation dialog when downloading the model data"
            ))
        }
    }

    private func handleTap() {
        if chat.imageModel.state?.isNotDownloaded == true {
            showingConfirmation = true
            return
        }

        withAnimation(.easeInOut(duration: ToolConstants.animationDuration)) {
            selectedAction = .imageGeneration([.imageGeneration])
        }
    }

    private func downloadAndSwitch() {
        Task(priority: .userInitiated) {
            #if os(iOS)
                let impactGenerator: UIImpactFeedbackGenerator =
                    UIImpactFeedbackGenerator(style: .medium)
                impactGenerator.prepare()
                impactGenerator.impactOccurred()
            #endif

            await modelActions.download(modelId: chat.imageModel.id)

            await MainActor.run {
                showingConfirmation = false
                withAnimation(.easeInOut(duration: ToolConstants.animationDuration)) {
                    selectedAction = .imageGeneration([.imageGeneration])
                }
            }
        }
    }

    private func formattedSize(for model: Model) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(model.size), countStyle: .file)
    }
}
