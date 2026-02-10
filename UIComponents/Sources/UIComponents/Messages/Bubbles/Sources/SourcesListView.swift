import Database
import SwiftUI

// MARK: - SourcesListView

public struct SourcesListView: View {
    let toolExecutions: [ToolExecution]
    @Binding var showingSourcesView: Bool

    public var body: some View {
        List {
            ForEach(toolExecutions) { execution in
                if let sources = execution.sources, !sources.isEmpty {
                    Section(header: Text(execution.toolName)) {
                        ForEach(sources) { source in
                            SourceRowView(source: source)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("Sources", bundle: .module))
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var showingSourcesView: Bool = false
        SourcesListView(toolExecutions: [], showingSourcesView: $showingSourcesView)
    }
#endif
