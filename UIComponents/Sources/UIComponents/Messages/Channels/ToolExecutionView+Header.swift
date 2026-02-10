import SwiftUI

extension ToolExecutionView {
    var toolHeader: some View {
        Button {
            guard hasContent else {
                return
            }
            if isExpandedValue == false {
                // If the user expands a tool while the assistant is streaming, stop auto-scroll
                // so the UI doesn't yank the disclosure offscreen mid-read.
                controller.suppressAutoScroll?()
            }
            withAnimation(
                .spring(
                    response: ToolExecutionViewConstants.animationResponse,
                    dampingFraction: ToolExecutionViewConstants.animationDamping
                )
            ) {
                toggleExpanded()
            }
        } label: {
            HStack(spacing: ToolExecutionViewConstants.headerSpacing) {
                statusIconView
                toolNameView
                statusSeparatorView
                statusTextView

                Spacer()

                headerTrailingView
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toolExecution.header.\(toolExecution.id.uuidString)")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            Text("\(toolDisplayName), \(statusText)", bundle: .module)
        )
        .accessibilityHint(
            hasContent
                ? Text(
                    "Tap to \(isExpandedValue ? "collapse" : "expand") details",
                    bundle: .module
                )
                : Text(verbatim: "")
        )
    }

    var statusIconView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: ToolExecutionViewConstants.iconSize, weight: .medium))
            .foregroundColor(statusColor)
            .opacity(ToolExecutionViewConstants.iconOpacity)
            .accessibilityHidden(true)
    }

    var toolNameView: some View {
        Text(toolDisplayName)
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(Color.textPrimary)
    }

    var statusSeparatorView: some View {
        Text(verbatim: ".")
            .foregroundColor(.secondary.opacity(ToolExecutionViewConstants.secondaryOpacity))
    }

    var statusTextView: some View {
        Text(statusText)
            .font(.caption)
            .foregroundColor(statusColor)
    }

    @ViewBuilder var headerTrailingView: some View {
        if toolExecution.state == .executing {
            progressIndicator
        } else if hasContent {
            chevronIndicator
        }
    }

    @ViewBuilder var progressIndicator: some View {
        if let progress = toolExecution.progress {
            ProgressView(value: progress)
                .scaleEffect(ToolExecutionViewConstants.progressScale)
                .accessibilityLabel(Text("Executing", bundle: .module))
        } else {
            ProgressView()
                .scaleEffect(ToolExecutionViewConstants.progressScale)
                .accessibilityLabel(Text("Executing", bundle: .module))
        }
    }

    var chevronIndicator: some View {
        Image(systemName: isExpandedValue ? "chevron.up" : "chevron.down")
            .font(.system(size: ToolExecutionViewConstants.chevronSize, weight: .medium))
            .foregroundColor(Color.textSecondary)
            .accessibilityHidden(true)
    }
}
