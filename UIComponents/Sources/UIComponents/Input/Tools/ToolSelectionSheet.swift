import Abstractions
import Database
import SwiftUI

internal struct ToolSelectionSheet: View {
    let chat: Chat
    let onToolSelected: (ToolIdentifier) -> Void
    let onToolConfirmationNeeded: (ToolIdentifier, Model) -> Void
    let onDismiss: () -> Void

    var body: some View {
        platformSpecificView()
    }

    @ViewBuilder
    private func platformSpecificView() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                toolsListContent()
                    .navigationTitle(String(
                        localized: "Tools",
                        bundle: .module,
                        comment: "Navigation title for tools selection"
                    ))
                    .navigationBarTitleDisplayMode(.large)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        #else
            VStack(alignment: .leading, spacing: 0) {
                Text(String(
                    localized: "Tools",
                    bundle: .module,
                    comment: "Navigation title for tools selection"
                ))
                .font(.headline)
                .padding(.horizontal, ToolConstants.sheetSpacing)
                .padding(.vertical, ToolConstants.popoverTitleVerticalPadding)

                Divider()

                toolsListContent()
            }
        #endif
    }

    private func toolsListContent() -> some View {
        VStack(alignment: .leading, spacing: ToolConstants.sheetSpacing) {
            ForEach(availableTools, id: \.self) { tool in
                ToolRow(tool: tool, chat: chat) { selectedTool in
                    handleToolSelection(selectedTool)
                }
            }
            Spacer()
        }
        .padding(.horizontal, ToolConstants.sheetSpacing)
        .padding(.top, ToolConstants.sheetSpacing)
    }

    private var availableTools: [ToolIdentifier] {
        var tools: [ToolIdentifier] = []

        // Add Create Image tool only if device has enough memory
        #if os(iOS) || os(macOS)
            if ProcessInfo.processInfo.physicalMemory > ToolConstants.minimumMemoryToDraw {
                tools.append(.imageGeneration)
            }
        #endif

        // Add Think Longer tool only if device has enough memory
        if ProcessInfo.processInfo.physicalMemory > ToolConstants.minimumMemoryToReason {
            tools.append(.reasoning)
        }

        // Search Web is always available
        tools.append(.browser)

        // Add HealthKit tool only on iOS
        #if os(iOS)
            tools.append(.healthKit)
        #endif

        return tools
    }

    private func handleToolSelection(_ tool: ToolIdentifier) {
        // Check if tool requires model download
        Task {
            let model: Model = getModelForTool(tool)

            await MainActor.run {
                if model.state?.isNotDownloaded == true {
                    onToolConfirmationNeeded(tool, model)
                    onDismiss()
                    return
                }
                onToolSelected(tool)
                onDismiss()
            }
        }
    }

    private func getModelForTool(_ tool: ToolIdentifier) -> Model {
        switch tool {
        case .imageGeneration:
            chat.imageModel

        case .reasoning:
            // Use the unified language model for reasoning
            chat.languageModel

        case .browser:
            chat.languageModel

        case .python:
            chat.languageModel

        case .functions:
            chat.languageModel

        case .healthKit:
            chat.languageModel

        case .weather:
            chat.languageModel

        case .duckduckgo:
            chat.languageModel

        case .braveSearch:
            chat.languageModel
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        ToolSelectionSheet(
            chat: .preview,
            onToolSelected: { tool in
                print("Selected tool: \(tool.rawValue)")
            },
            onToolConfirmationNeeded: { tool, model in
                print("Tool \(tool.rawValue) needs confirmation for model \(model.name)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
#endif
