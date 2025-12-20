import Database
import SwiftUI

// MARK: - AssistantImageBubbleView

public struct AssistantImageBubbleView: View {
    @Bindable var message: Message

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MessageLayout.spacing) {
                if message.metrics == nil {
                    loadingText
                        .padding(.bottom)
                }

                if let image = message.responseImage {
                    ImageView(attachment: image)
                }
            }
            Spacer()
        }
    }

    private var loadingText: some View {
        ImageGenerationLoadingView()
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var message: Message = Message.previewWithResponseImage
        AssistantImageBubbleView(message: message)
    }
#endif
