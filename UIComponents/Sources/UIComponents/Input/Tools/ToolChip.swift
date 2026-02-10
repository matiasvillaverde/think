import Abstractions
import SwiftUI
#if os(iOS)
    import UIKit
#endif

internal struct ToolChip: View {
    let tool: ToolIdentifier
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: ToolConstants.chipSpacing) {
            Image(systemName: iconName)
                .font(.system(size: ToolConstants.chipIconSize, weight: .medium))
                .foregroundColor(.marketingSecondaryText)
                .accessibilityHidden(true)

            Button(
                action: {
                    withAnimation(.easeInOut(duration: ToolConstants.animationDuration)) {
                        #if os(iOS)
                            let impactGenerator: UIImpactFeedbackGenerator =
                                UIImpactFeedbackGenerator(style: .light)
                            impactGenerator.prepare()
                            impactGenerator.impactOccurred()
                        #endif
                        onRemove()
                    }
                },
                label: {
                    Image(systemName: "xmark")
                        .font(.system(size: ToolConstants.chipRemoveIconSize, weight: .medium))
                        .foregroundColor(.marketingSecondaryText)
                        .accessibilityLabel(String(
                            localized: "Remove tool",
                            bundle: .module,
                            comment: "Button to remove selected tool"
                        ))
                }
            )
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ToolConstants.chipHorizontalPadding)
        .padding(.vertical, ToolConstants.chipVerticalPadding)
        .background(Color.accentColor)
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "\(tool.rawValue) selected",
            bundle: .module,
            comment: "Accessibility label for selected tool"
        ))
    }

    private var iconName: String {
        switch tool {
        case .imageGeneration:
            "photo"

        case .browser:
            "globe"

        case .functions:
            "hammer.fill"

        case .python:
            "laptopcomputer"

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

        case .cron:
            "calendar.badge.clock"

        case .canvas:
            "square.and.pencil"

        case .nodes:
            "network"
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        HStack {
            ToolChip(tool: .imageGeneration) {
                // no-op
            }

            ToolChip(tool: .browser) {
                // no-op
            }
        }
        .padding()
    }
#endif
