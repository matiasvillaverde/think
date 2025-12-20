import SwiftUI

// Extracted component for better separation of concerns
internal struct PromptItemView: View {
    let title: String
    let subtitle: String
    let index: Int
    let isAnimating: Bool
    let onTapAction: () -> Void

    internal init(
        title: String,
        subtitle: String,
        index: Int,
        isAnimating: Bool,
        onTapAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.index = index
        self.isAnimating = isAnimating
        self.onTapAction = onTapAction
    }

    internal var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .bold()
                .font(.body)
            Text(subtitle)
                .fontWeight(.light)
                .font(.footnote)
        }
        .padding()
        .background(Color.backgroundPrimary)
        .cornerRadius(PromptsView.Constants.kCornerRadius)
        .onTapGesture(perform: onTapAction)
        // Animation properties
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : PromptsView.Constants.animationInitialYOffset)
        .animation(
            .easeInOut.delay(PromptsView.Constants.animationItemDelayFactor * Double(index)),
            value: isAnimating
        )
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
    #Preview {
        HStack {
            PromptItemView(
                title: "Code Review Assistant",
                subtitle: "analyze and improve code quality",
                index: 0,
                isAnimating: true
            ) {
                print("Tapped")
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
#endif
