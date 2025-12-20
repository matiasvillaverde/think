import SwiftUI

/// A standardized action button with hover effect and animation
internal struct HoverableActionButton: View {
    /// The SF Symbol name for the button icon
    let systemName: String

    /// The filled SF Symbol name that appears during animation
    let filledSystemName: String

    /// The accessibility label for the button
    let accessibilityLabel: String

    /// The action to perform when tapped
    let action: () -> Void

    /// The color to use for the confirmation icon and background
    let confirmationColor: Color

    /// Tracks the state of the button animation
    @State private var isAnimating: Bool = false

    /// Tracks whether the button is being hovered
    @State private var isHovering: Bool = false

    init(
        systemName: String,
        filledSystemName: String?,
        accessibilityLabel: String,
        confirmationColor: Color = Color.iconConfirmation,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.filledSystemName = filledSystemName ?? systemName + ".fill"
        self.accessibilityLabel = accessibilityLabel
        self.confirmationColor = confirmationColor
        self.action = action
    }

    var body: some View {
        Button {
            withAnimation(.spring(
                response: ButtonConstants.springAnimationResponse,
                dampingFraction: ButtonConstants.springAnimationDamping
            )) {
                isAnimating = true
            }

            action()

            // Reset after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + ButtonConstants.animationDuration) {
                withAnimation(.spring(
                    response: ButtonConstants.springAnimationResponse,
                    dampingFraction: ButtonConstants.springAnimationDamping
                )) {
                    isAnimating = false
                }
            }
        } label: {
            ZStack {
                // Animated circle background
                Circle()
                    .fill(confirmationColor.opacity(ButtonConstants.circleBackgroundOpacity))
                    .frame(width: ButtonConstants.circleSize, height: ButtonConstants.circleSize)
                    .scaleEffect(isAnimating ? ButtonConstants.normal : ButtonConstants.noOpacity)
                    .opacity(isAnimating ? ButtonConstants.fullOpacity : ButtonConstants.noOpacity)

                // Animated filled icon
                Image(systemName: filledSystemName)
                    .font(.callout)
                    .foregroundColor(confirmationColor)
                    .scaleEffect(isAnimating ? ButtonConstants.normal : ButtonConstants.small)
                    .opacity(isAnimating ? ButtonConstants.fullOpacity : ButtonConstants.noOpacity)

                // Original icon
                Image(systemName: systemName)
                    .font(.callout)
                    .foregroundColor(isHovering ? Color.iconHovered : Color.iconSecondary)
                    .fontWeight(isHovering ? .bold : .regular)
                    .scaleEffect(isAnimating ? ButtonConstants.small :
                        (isHovering ? ButtonConstants.hoverScale : ButtonConstants.normal))
                    .opacity(isAnimating ? ButtonConstants.noOpacity : ButtonConstants.fullOpacity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: ButtonConstants.hoverAnimationDuration)) {
                isHovering = hovering
            }
        }
    }
}
