import SwiftUI

/// Reusable circle button component
internal struct CircleButton: View {
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: LayoutVoice.Size.circleButtonFont))
                .foregroundStyle(Color.iconPrimary)
                .frame(
                    width: LayoutVoice.Size.circleButton,
                    height: LayoutVoice.Size.circleButton
                )
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .accessibilityLabel(accessibilityLabel)
        .shadow(
            color: .black.opacity(StyleConstants.Opacity.buttonShadow),
            radius: StyleConstants.Shadow.buttonRadius,
            x: StyleConstants.Shadow.offset,
            y: StyleConstants.Shadow.buttonOffsetY
        )
    }
}
