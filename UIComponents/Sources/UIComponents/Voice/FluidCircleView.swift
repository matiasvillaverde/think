import SwiftUI

/// Circle view with fluid animation inside
internal struct FluidCircleView: View {
    let animationSpeed: Double
    let colorIntensity: Double

    var body: some View {
        ZStack {
            // Animated fluid content
            FluidAnimationView(
                speed: animationSpeed,
                intensity: colorIntensity
            )
            .clipShape(Circle())

            // Optional overlay effects
            Circle()
                .strokeBorder(
                    .white.opacity(StyleConstants.Opacity.borderOverlay),
                    lineWidth: StyleConstants.Border.width
                )
        }
        .background(
            Circle()
                .fill(Color.white)
                .shadow(
                    color: .blue.opacity(StyleConstants.Opacity.shadowEffect),
                    radius: StyleConstants.Shadow.radius,
                    x: StyleConstants.Shadow.offset,
                    y: StyleConstants.Shadow.offset
                )
        )
    }
}
