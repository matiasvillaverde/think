import Database
import SwiftUI

// MARK: - Model Group View

internal struct ModelGroupView: View {
    private let models: [Model]
    private let title: String
    private let chat: Chat

    init(models: [Model], title: String, chat: Chat) {
        self.models = models
        self.title = title
        self.chat = chat
    }

    var body: some View {
        Group {
            if !models.isEmpty {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.standard) {
                    SectionHeaderView(title: title)
                    ModelSectionView(models: models, chat: chat)
                }
            }
        }
    }
}
