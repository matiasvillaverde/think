import Database
import SwiftUI

// **MARK: - SourcesButton**
public struct SourcesButton: View {
    var toolExecutions: [ToolExecution]
    @State private var showingSourcesView: Bool = false

    private enum Layout {
        static let minWidth: CGFloat = 400
        static let minHeight: CGFloat = 500
    }

    public var body: some View {
        Button {
            showingSourcesView = true
        } label: {
            HStack(spacing: SourceViewConstants.buttonIconSpacing) {
                Image(systemName: "link")
                    .font(.system(size: SourceViewConstants.buttonFontSize, weight: .medium))
                    .accessibilityLabel(
                        String(localized: "Sources icon", bundle: .module)
                    )
                Text("Sources", bundle: .module)
                    .font(.system(size: SourceViewConstants.buttonFontSize, weight: .medium))
            }
            .padding(.horizontal, SourceViewConstants.buttonHorizontalPadding)
            .padding(.vertical, SourceViewConstants.buttonVerticalPadding)
            .foregroundColor(Color.textPrimary)
        }
        #if os(macOS)
        .popover(isPresented: $showingSourcesView) {
            SourcesListView(toolExecutions: toolExecutions, showingSourcesView: $showingSourcesView)
                .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
                .background(Color.backgroundPrimary)
                .presentationCompactAdaptation(.popover)
        }
        #else
        .sheet(isPresented: $showingSourcesView) {
            SourcesListView(toolExecutions: toolExecutions, showingSourcesView: $showingSourcesView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        #endif
    }
}

#if DEBUG
    #Preview {
        SourcesButton(toolExecutions: [])
    }
#endif
