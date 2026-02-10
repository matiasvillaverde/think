import Abstractions
import Database
import SwiftUI

internal struct CapabilitiesToolsSection: View {
    let chat: Chat
    let toolOrder: [ToolIdentifier]
    let effectiveTools: Set<ToolIdentifier>
    let onToggle: (ToolIdentifier, Bool) -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: CapabilitiesSheet.Constants.sectionSpacing) {
            Text(String(localized: "Tools", bundle: .module))
                .font(.subheadline.weight(.semibold))

            ForEach(toolOrder, id: \.self) { tool in
                CapabilityToolRow(
                    tool: tool,
                    chat: chat,
                    isEnabled: effectiveTools.contains(tool),
                    onToggle: onToggle
                )
            }
        }
    }
}
