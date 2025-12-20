import Database
import SwiftUI

internal struct ModelIndicatorView: View {
    @Bindable var model: Model
    @Bindable var chat: Chat

    private var isSelectedForText: Bool {
        model == chat.languageModel
    }

    private var isSelectedForImage: Bool {
        model == chat.imageModel
    }

    var body: some View {
        StateIndicator(
            icon: "checkmark.circle.fill",
            text: selectionText(),
            color: Color.iconConfirmation
        )
    }

    private func selectionText() -> String {
        if isSelectedForText, isSelectedForImage {
            return String(
                localized: "Selected for Text & Image",
                bundle: .module,
                comment: "Model selected for both text and image generation"
            )
        }
        if isSelectedForText {
            return String(
                localized: "Selected for Text",
                bundle: .module,
                comment: "Model selected for text generation"
            )
        }
        if isSelectedForImage {
            return String(
                localized: "Selected for Image",
                bundle: .module,
                comment: "Model selected for image generation"
            )
        }
        // This shouldn't happen but let's handle it gracefully
        return String(
            localized: "Selected",
            bundle: .module,
            comment: "Model is selected"
        )
    }
}
