import SwiftUI

// MARK: - Constants

/// Constants for button styling and behavior in message bubbles
public enum ButtonConstants {
    // Layout
    static let buttonSpacing: CGFloat = 10
    static let verticalPadding: CGFloat = 8

    // Animations
    static let animationDuration: Double = 1.5
    static let springAnimationResponse: Double = 0.3
    static let springAnimationDamping: Double = 0.6
    static let hoverAnimationDuration: Double = 0.2

    // Scaling
    static let normal: CGFloat = 1.0
    static let small: CGFloat = 0.5
    static let hoverScale: CGFloat = 1.1

    // Opacity
    static let fullOpacity: Double = 1.0
    static let noOpacity: Double = 0.0
    static let circleBackgroundOpacity: Double = 0.2

    // Sizes
    static let circleSize: CGFloat = 30

    // App review
    static let minLikesBeforeReview: Int = 2

    // Buttons
    static let iconSize: CGFloat = 25
    static let opacity: Double = 0.9
    static let springAnimation: Animation = .spring()
}
