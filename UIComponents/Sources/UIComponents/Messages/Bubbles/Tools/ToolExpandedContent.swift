import Abstractions
import SwiftUI

// MARK: - ToolExpandedContent

public struct ToolExpandedContent: View {
    let toolRequest: ToolRequest?
    let toolResponse: ToolResponse?

    public var body: some View {
        VStack(alignment: .leading, spacing: ToolUsageConstants.contentSpacing) {
            // Input section
            if let request = toolRequest {
                ToolDataSection(
                    title: String(localized: "Input:", bundle: .module),
                    content: request.arguments
                )
            }

            // Result section (if available)
            if let response = toolResponse {
                ToolDataSection(
                    title: String(localized: "Result:", bundle: .module),
                    content: response.result
                )
                .padding(.top, ToolUsageConstants.sectionTopPadding)
                .padding(.bottom, ToolUsageConstants.containerBottomPadding)
            }
        }
        .transition(.opacity)
    }
}
