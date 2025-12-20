import SwiftUI

/// A button style for DiscoveryModelCard that provides press animations
/// without interfering with scroll gestures
internal struct DiscoveryModelCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed ?
                    DesignConstants.Scale.pressed :
                    DesignConstants.Scale.normal
            )
            .animation(
                .spring(
                    response: DesignConstants.Animation.quick,
                    dampingFraction: DesignConstants.Animation.pressDamping
                ),
                value: configuration.isPressed
            )
    }
}
