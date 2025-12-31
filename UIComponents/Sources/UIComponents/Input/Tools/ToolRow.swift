import Abstractions
import Database
import SwiftUI

internal struct ToolRow: View {
    @Environment(\.toolValidator)
    private var toolValidator: ToolValidating?

    let tool: ToolIdentifier
    let chat: Chat
    let onSelection: (ToolIdentifier) -> Void

    @State private var validationResult: ToolValidationResult = .available
    @State private var isValidating: Bool = false

    private enum Constants {
        static let spacingSmall: CGFloat = 4
        static let scaleSmall: CGFloat = 0.8
    }

    var body: some View {
        toolButton
            .buttonStyle(.plain)
            .disabled(!validationResult.isAvailable && !validationResult.requiresDownload)
            .accessibilityLabel(accessibilityLabel)
            .task {
                await validateTool()
            }
    }

    private var toolButton: some View {
        Button(
            action: {
                handleToolSelection()
            },
            label: {
                HStack(spacing: ToolConstants.rowSpacing) {
                    toolIcon

                    toolDescription

                    Spacer()

                    trailingContent
                }
                .padding(.vertical, ToolConstants.rowVerticalPadding)
            }
        )
    }

    private var toolIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: ToolConstants.rowIconSize, weight: .medium))
            .foregroundColor(iconColor)
            .frame(
                width: ToolConstants.rowIconFrame,
                height: ToolConstants.rowIconFrame
            )
            .accessibilityHidden(true)
    }

    private var toolDescription: some View {
        VStack(alignment: .leading, spacing: Constants.spacingSmall) {
            Text(tool.rawValue)
                .font(.system(size: ToolConstants.rowTextSize, weight: .medium))
                .foregroundColor(textColor)

            if case let .insufficientMemory(required, _) = validationResult {
                Text(String(
                    localized: "Requires \(formattedMemorySize(required))",
                    bundle: .module,
                    comment: "Memory requirement for tool"
                ))
                .font(.caption)
                .foregroundColor(.textSecondary)
            }
        }
    }

    private var trailingContent: some View {
        Group {
            if isValidating {
                ProgressView()
                    .scaleEffect(Constants.scaleSmall)
            } else if case let .requiresDownload(_, size) = validationResult {
                Text(formattedFileSize(size))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private var iconName: String {
        switch tool {
        case .imageGeneration:
            "photo"

        case .reasoning:
            "lightbulb"

        case .browser:
            "globe"

        case .python:
            "laptopcomputer"

        case .functions:
            "hammer.fill"

        case .healthKit:
            "heart.text.square"

        case .weather:
            "cloud.sun"

        case .duckduckgo:
            "magnifyingglass"

        case .braveSearch:
            "magnifyingglass.circle"

        case .memory:
            "brain.head.profile"

        case .subAgent:
            "person.2"

        case .workspace:
            "folder"
        }
    }

    private var iconColor: Color {
        switch validationResult {
        case .available, .requiresDownload:
            .iconPrimary

        case .insufficientMemory, .notSupported:
            .iconSecondary
        }
    }

    private var textColor: Color {
        switch validationResult {
        case .available, .requiresDownload:
            .textPrimary

        case .insufficientMemory, .notSupported:
            .textSecondary
        }
    }

    private var accessibilityLabel: String {
        var label: String = tool.rawValue

        switch validationResult {
        case .available:
            label += String(
                localized: ", available",
                bundle: .module,
                comment: "Accessibility suffix for available tool"
            )

        case let .requiresDownload(_, size):
            label += String(
                localized: ", requires download of \(formattedFileSize(size))",
                bundle: .module,
                comment: "Accessibility suffix for tool requiring download"
            )

        case let .insufficientMemory(required, _):
            label += String(
                localized: ", requires \(formattedMemorySize(required)) of memory",
                bundle: .module,
                comment: "Accessibility suffix for tool requiring more memory"
            )

        case .notSupported:
            label += String(
                localized: ", not supported on this device",
                bundle: .module,
                comment: "Accessibility suffix for unsupported tool"
            )
        }

        return label
    }

    private func formattedMemorySize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func formattedFileSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func validateTool() async {
        guard let validator = toolValidator else {
            validationResult = .available
            return
        }

        isValidating = true
        defer { isValidating = false }

        do {
            validationResult = try await validator.validateToolRequirements(tool, chatId: chat.id)
        } catch {
            validationResult = .notSupported
        }
    }

    private func handleToolSelection() {
        switch validationResult {
        case .available:
            onSelection(tool)

        case .requiresDownload:
            onSelection(tool)

        case .insufficientMemory, .notSupported:
            break
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 0) {
            ToolRow(
                tool: .imageGeneration,
                chat: .preview
            ) { tool in
                print("Selected \(tool.rawValue)")
            }

            Divider()

            ToolRow(
                tool: .reasoning,
                chat: .preview
            ) { tool in
                print("Selected \(tool.rawValue)")
            }

            Divider()

            ToolRow(
                tool: .browser,
                chat: .preview
            ) { tool in
                print("Selected \(tool.rawValue)")
            }
        }
        .padding()
    }
#endif
