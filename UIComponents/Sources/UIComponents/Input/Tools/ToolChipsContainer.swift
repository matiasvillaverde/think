import Abstractions
import SwiftUI

internal struct ToolChipsContainer: View {
    let tools: Set<ToolIdentifier>
    let onRemoveTool: (ToolIdentifier) -> Void

    var body: some View {
        HStack(spacing: ToolConstants.horizontalSpacing) {
            ForEach(Array(tools).sorted { $0.rawValue < $1.rawValue }, id: \.self) { tool in
                ToolChip(tool: tool) {
                    onRemoveTool(tool)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 16) {
            ToolChipsContainer(
                tools: [.imageGeneration]
            ) { _ in
                // no-op
            }

            ToolChipsContainer(
                tools: [.browser]
            ) { _ in
                // no-op
            }

            ToolChipsContainer(
                tools: [.imageGeneration, .browser]
            ) { _ in
                // no-op
            }
        }
        .padding()
    }
#endif
