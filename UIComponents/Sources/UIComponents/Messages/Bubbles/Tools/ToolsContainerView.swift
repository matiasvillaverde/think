import Database
import SwiftUI

// MARK: - ToolsContainerView

public struct ToolsContainerView: View {
    let toolExecutions: [ToolExecution]

    public var body: some View {
        VStack(alignment: .leading, spacing: ToolUsageConstants.contentSpacing) {
            ForEach(toolExecutions) { execution in
                ToolUsageView(toolExecution: execution)
            }
        }
        .padding(.top, ToolUsageConstants.sectionTopPadding)
    }
}

#if DEBUG
    #Preview {
        ToolsContainerView(toolExecutions: [])
    }
#endif
