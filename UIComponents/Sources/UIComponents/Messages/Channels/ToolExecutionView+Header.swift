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
                    response: Constants.animationResponse,
                    dampingFraction: Constants.animationDamping
                )
            ) {
                toggleExpanded()
            }
        } label: {
            HStack(spacing: Constants.headerSpacing) {
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
        .accessibilityLabel("\(toolDisplayName), \(statusText)")
        .accessibilityHint(
            hasContent ? "Tap to \(isExpandedValue ? "collapse" : "expand") details" : ""
        )
    }

    var statusIconView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: Constants.iconSize, weight: .medium))
            .foregroundColor(statusColor)
            .opacity(Constants.iconOpacity)
            .accessibilityHidden(true)
    }

    var toolNameView: some View {
        Text(toolDisplayName)
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(Color.textPrimary)
    }

    var statusSeparatorView: some View {
        Text(".")
            .foregroundColor(.secondary.opacity(Constants.secondaryOpacity))
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
                .scaleEffect(Constants.progressScale)
                .accessibilityLabel("Executing")
        } else {
            ProgressView()
                .scaleEffect(Constants.progressScale)
                .accessibilityLabel("Executing")
        }
    }

    var chevronIndicator: some View {
        Image(systemName: isExpandedValue ? "chevron.up" : "chevron.down")
            .font(.system(size: Constants.chevronSize, weight: .medium))
            .foregroundColor(Color.textSecondary)
            .accessibilityHidden(true)
    }
}
