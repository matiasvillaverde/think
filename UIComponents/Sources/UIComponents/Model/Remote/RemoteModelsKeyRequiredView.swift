import SwiftUI

internal struct RemoteModelsKeyRequiredView: View {
    let providerName: String
    let onAddKey: () -> Void

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.standard) {
            ContentUnavailableView(
                "Add an API Key",
                systemImage: "key.fill",
                description: Text(
                    "Add your \(providerName) API key to load models.",
                    bundle: .module
                )
            )
            Button(action: onAddKey) {
                Text("Add API Key", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#if DEBUG
#Preview {
    RemoteModelsKeyRequiredView(providerName: "OpenRouter") {
        _ = 0
    }
}
#endif
