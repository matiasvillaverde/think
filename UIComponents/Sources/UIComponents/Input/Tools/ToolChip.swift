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

        case .reasoning:
            "lightbulb"

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
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        HStack {
            ToolChip(tool: .imageGeneration) {
                print("Remove image generation")
            }

            ToolChip(tool: .reasoning) {
                print("Remove reasoning")
            }

            ToolChip(tool: .browser) {
                print("Remove web search")
            }
        }
        .padding()
    }
#endif
