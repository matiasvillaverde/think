import Database
import SwiftUI

// **MARK: - Model Card Section View**

internal struct ModelSectionView: View {
    private let models: [Model]
    @Bindable var chat: Chat

    private let opacity: Double = 0.7

    init(models: [Model], chat: Chat) {
        self.models = models
        self.chat = chat
    }

    var body: some View {
        LazyVStack(spacing: DesignConstants.Spacing.standard) {
            ForEach(models, id: \.name) { model in
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                    ModelCard(chat: chat, model: model)
                }
            }

            footerView
        }
    }

    // Extract footer view to reduce main body size
    private var footerView: some View {
        Text(
            "Download more models for free from the \"Discover\" tabs.",
            bundle: .module
        )
        .font(.caption)
        .foregroundColor(Color.textSecondary)
        .opacity(opacity)
        .padding()
        .multilineTextAlignment(.center)
    }
}
