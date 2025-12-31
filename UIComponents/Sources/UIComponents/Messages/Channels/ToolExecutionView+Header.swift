import SwiftUI

extension ToolExecutionView {
    var toolHeader: some View {
        HStack(spacing: Constants.headerSpacing) {
            statusIconView
            toolNameView
            statusSeparatorView
            statusTextView

            Spacer()

            headerTrailingView
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if hasContent {
                withAnimation(
                    .spring(
                        response: Constants.animationResponse,
                        dampingFraction: Constants.animationDamping
                    )
                ) {
                    toggleExpanded()
                }
            }
        }
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
            .foregroundColor(.primary)
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
            .foregroundColor(.secondary)
            .accessibilityHidden(true)
    }
}
