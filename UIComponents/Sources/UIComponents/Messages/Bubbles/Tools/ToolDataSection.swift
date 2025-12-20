import SwiftUI

// MARK: - ToolDataSection

public struct ToolDataSection: View {
    let title: String
    let content: String

    public var body: some View {
        VStack(alignment: .leading, spacing: ToolUsageConstants.sectionSpacing) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, ToolUsageConstants.contentHorizontalPadding)

            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding(ToolUsageConstants.jsonPadding)
                .background(Color.backgroundSecondary)
                .cornerRadius(ToolUsageConstants.cornerRadius)
                .padding(.horizontal, ToolUsageConstants.contentHorizontalPadding)
        }
    }
}
