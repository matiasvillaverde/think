import SwiftUI

public struct SearchScopesContent: View {
    public var body: some View {
        Group {
            Text("All", bundle: .module).tag(ChatSearchScope.all)
            Text("Title", bundle: .module).tag(ChatSearchScope.name)
            Text("Messages", bundle: .module).tag(ChatSearchScope.messages)
        }
    }
}

#Preview {
    SearchScopesContent()
}
