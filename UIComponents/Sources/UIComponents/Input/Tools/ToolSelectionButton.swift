import Abstractions
import Database
import SwiftUI
#if os(iOS)
    import UIKit
#endif

internal struct ToolSelectionButton: View {
    @Bindable var chat: Chat
    @Binding var selectedAction: Action
    @State private var showingToolsSheet: Bool = false
    @State private var showingConfirmation: Bool = false
    @State private var pendingTool: ToolIdentifier?
    @State private var confirmationModel: Model?
    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    private static let toolActionMap: [ToolIdentifier: Action] = [
        .imageGeneration: .imageGeneration([.imageGeneration]),
        .browser: .textGeneration([.browser]),
        .python: .textGeneration([.python]),
        .functions: .textGeneration([.functions]),
        .healthKit: .textGeneration([.healthKit]),
        .weather: .textGeneration([.weather]),
        .duckduckgo: .textGeneration([.duckduckgo]),
        .braveSearch: .textGeneration([.braveSearch]),
        .subAgent: .textGeneration([.subAgent]),
        .workspace: .textGeneration([.workspace])
    ]

    var body: some View {
        Button {
            showingToolsSheet = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: ToolConstants.toolsButtonIconSize, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .accessibilityLabel(String(
                    localized: "Tools",
                    bundle: .module,
                    comment: "Button to show available tools"
                ))
        }
        .buttonStyle(.plain)
        .frame(width: ToolConstants.toolsButtonSize, height: ToolConstants.toolsButtonSize)
        #if os(macOS)
            .popover(isPresented: $showingToolsSheet) {
                ToolSelectionSheet(
                    chat: chat,
                    onToolSelected: { tool in
                        selectTool(tool)
                    },
                    onToolConfirmationNeeded: { tool, model in
                        handleToolConfirmationNeeded(tool, model)
                    },
                    onDismiss: {
                        showingToolsSheet = false
                    }
                )
                .frame(
                    minWidth: ToolConstants.popoverMinWidth,
                    minHeight: ToolConstants.popoverMinHeight
                )
                .presentationCompactAdaptation(.popover)
            }
        #else
            .sheet(isPresented: $showingToolsSheet) {
                ToolSelectionSheet(
                    chat: chat,
                    onToolSelected: { tool in
                        selectTool(tool)
                    },
                    onToolConfirmationNeeded: { tool, model in
                        handleToolConfirmationNeeded(tool, model)
                    },
                    onDismiss: {
                        showingToolsSheet = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        #endif
        .confirmationDialog(
            Text(String(
                localized: "Download Confirmation",
                bundle: .module,
                comment: "Title for the confirmation dialog when downloading a model"
            )),
            isPresented: $showingConfirmation,
            titleVisibility: .automatic
        ) {
            confirmationButtons
        } message: {
            if let tool = pendingTool, let model = confirmationModel {
                Text(String(
                    localized: """
                    To use \(tool
                        .rawValue), a model needs to be downloaded from the internet. \
                    This will require \(formattedSize(for: model)) of data. \
                    Please confirm to proceed.
                    """,
                    bundle: .module,
                    comment: "Message for the confirmation dialog when downloading a model"
                ))
            }
        }
    }

    // MARK: - Private Methods

    private func selectTool(_ tool: ToolIdentifier) {
        withAnimation(.easeInOut(duration: ToolConstants.animationDuration)) {
            guard let action = action(for: tool) else {
                return
            }
            selectedAction = action
        }
        showingToolsSheet = false
    }

    private func action(for tool: ToolIdentifier) -> Action? {
        Self.toolActionMap[tool]
    }

    private func handleToolConfirmationNeeded(_ tool: ToolIdentifier, _ model: Model) {
        pendingTool = tool
        confirmationModel = model
        showingToolsSheet = false
        showingConfirmation = true
    }

    private func handleConfirmedToolSelection() {
        guard let tool = pendingTool else {
            return
        }

        selectTool(tool)

        // Reset state
        pendingTool = nil
        confirmationModel = nil
        showingConfirmation = false
    }

    private var confirmationButtons: some View {
        Group {
            if let model = confirmationModel {
                Button(
                    String(
                        localized: "Download \(formattedSize(for: model)) Now",
                        bundle: .module,
                        comment: "Button confirmation to download the model data"
                    ),
                    role: .none
                ) {
                    downloadAndConfirm()
                }
            }
            Button(
                String(
                    localized: "Cancel",
                    bundle: .module,
                    comment: "Button confirmation to cancel downloading the model data"
                ),
                role: .cancel
            ) {
                showingConfirmation = false
            }
        }
    }

    private func formattedSize(for model: Model) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(model.size),
            countStyle: .file
        )
    }

    private func downloadAndConfirm() {
        guard let model = confirmationModel else {
            return
        }
        Task(priority: .userInitiated) {
            // Add haptic feedback on download confirmation
            #if os(iOS)
                let impactGenerator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(
                    style: .medium
                )
                impactGenerator.prepare()
                impactGenerator.impactOccurred()
            #endif

            // Start download
            await modelActions.download(modelId: model.id)

            // Call confirmation callback
            await MainActor.run {
                handleConfirmedToolSelection()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        @Previewable @State var selectedAction: Action = .textGeneration([])

        HStack {
            ToolSelectionButton(
                chat: chat,
                selectedAction: $selectedAction
            )

            ToolSelectionButton(
                chat: chat,
                selectedAction: $selectedAction
            )
            .background(Color.paletteGray.opacity(0.2))
        }
        .padding()
    }
#endif
