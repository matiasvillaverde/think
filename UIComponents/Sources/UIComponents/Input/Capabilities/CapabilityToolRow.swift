import Abstractions
import Database
import SwiftUI

internal struct CapabilityToolRow: View {
    @Environment(\.toolValidator)
    private var toolValidator: ToolValidating?

    let tool: ToolIdentifier
    let chat: Chat
    let isEnabled: Bool
    let onToggle: (ToolIdentifier, Bool) -> Void

    @State private var validationResult: ToolValidationResult = .available
    @State private var isValidating: Bool = false

    private enum Constants {
        static let spacingSmall: CGFloat = 4
        static let toggleScale: CGFloat = 0.9
        static let progressScale: CGFloat = 0.8
    }

    var body: some View {
        row
        .padding(.vertical, ToolConstants.rowVerticalPadding)
        .task {
            await validateTool()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(tool.rawValue))
    }

    private var row: some View {
        HStack(spacing: ToolConstants.rowSpacing) {
            iconView
            labelsView
            Spacer()
            trailingControl
        }
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: ToolConstants.rowIconSize, weight: .medium))
            .foregroundColor(iconColor)
            .frame(
                width: ToolConstants.rowIconFrame,
                height: ToolConstants.rowIconFrame
            )
            .accessibilityHidden(true)
    }

    private var labelsView: some View {
        VStack(alignment: .leading, spacing: Constants.spacingSmall) {
            Text(tool.rawValue)
                .font(.system(size: ToolConstants.rowTextSize, weight: .medium))
                .foregroundColor(textColor)

            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }

    @ViewBuilder private var trailingControl: some View {
        if isValidating {
            ProgressView()
                .scaleEffect(Constants.progressScale)
        } else {
            Toggle(
                "",
                isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        let canToggle: Bool =
                            validationResult.isAvailable || validationResult.requiresDownload
                        guard canToggle else {
                            return
                        }
                        onToggle(tool, newValue)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .scaleEffect(Constants.toggleScale)
            .disabled(!validationResult.isAvailable && !validationResult.requiresDownload)
        }
    }

    private var subtitleText: String? {
        switch validationResult {
        case let .requiresDownload(_, size):
            return String(
                localized: "Download required (\(formattedFileSize(size)))",
                bundle: .module,
                comment: "Subtitle indicating tool requires download"
            )

        case let .insufficientMemory(required, _):
            return String(
                localized: "Requires \(formattedMemorySize(required)) RAM",
                bundle: .module,
                comment: "Subtitle indicating insufficient memory"
            )

        case .notSupported:
            return String(
                localized: "Not supported on this device",
                bundle: .module,
                comment: "Subtitle indicating tool is not supported"
            )

        case .available:
            return nil
        }
    }

    private var iconName: String {
        switch tool {
        case .imageGeneration:
            return "photo"

        case .browser:
            return "globe"

        case .python:
            return "laptopcomputer"

        case .functions:
            return "hammer.fill"

        case .healthKit:
            return "heart.text.square"

        case .weather:
            return "cloud.sun"

        case .duckduckgo:
            return "magnifyingglass"

        case .braveSearch:
            return "magnifyingglass.circle"

        case .memory:
            return "brain.head.profile"

        case .subAgent:
            return "person.2"

        case .workspace:
            return "folder"

        case .cron:
            return "calendar.badge.clock"

        case .canvas:
            return "square.and.pencil"

        case .nodes:
            return "network"
        }
    }

    private var iconColor: Color {
        switch validationResult {
        case .available, .requiresDownload:
            return .iconPrimary

        case .insufficientMemory, .notSupported:
            return .iconSecondary
        }
    }

    private var textColor: Color {
        switch validationResult {
        case .available, .requiresDownload:
            return .textPrimary

        case .insufficientMemory, .notSupported:
            return .textSecondary
        }
    }

    private func validateTool() async {
        guard let validator = toolValidator else {
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

    private func formattedFileSize(_ bytes: UInt64) -> String {
        let clamped: Int64 = Int64(clamping: bytes)
        return ByteCountFormatter.string(fromByteCount: clamped, countStyle: .file)
    }

    private func formattedMemorySize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
