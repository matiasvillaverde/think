import Foundation
import SwiftUI

/// Constants used in onboarding views
public enum OnboardingConstants {
    // MARK: - Layout

    static let horizontalPadding: CGFloat = 40
    static let verticalPadding: CGFloat = 60
    static let sectionSpacing: CGFloat = 40
    static let itemSpacing: CGFloat = 24
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let largeSpacing: CGFloat = 16

    // MARK: - Animation

    static let animationDuration: TimeInterval = 0.8
    static let shortAnimationDuration: TimeInterval = 0.2
    static let delayIncrement: TimeInterval = 0.2
    static let gradientAnimationDuration: TimeInterval = 10
    static let particleAnimationDuration: TimeInterval = 2
    static let featureTransitionDuration: TimeInterval = 0.5
    static let featureRotationInterval: TimeInterval = 4

    // MARK: - Sizes

    static let logoRingSize: CGFloat = 140
    static let logoSize: CGFloat = 100
    static let glowRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 10
    static let lineWidth: CGFloat = 2
    static let titleFontSize: CGFloat = 48
    static let buttonHeight: CGFloat = 56
    static let buttonMaxWidth: CGFloat = 300
    static let cornerRadius: CGFloat = 28
    static let maxTextWidth: CGFloat = 500
    static let progressMaxWidth: CGFloat = 200

    // MARK: - Feature Card

    static let featureIconSize: CGFloat = 50
    static let featureCircleSize: CGFloat = 120
    static let featureCardHeight: CGFloat = 300
    static let featureMaxTextWidth: CGFloat = 400
    static let featureDotSize: CGFloat = 8

    // MARK: - Particle System

    static let particleCount: Int = 20
    static let particleMinSize: CGFloat = 4
    static let particleMaxSize: CGFloat = 8
    static let particleMinOpacity: Double = 0.3
    static let particleMaxOpacity: Double = 0.7
    static let particleMinVelocity: CGFloat = -20
    static let particleMaxVelocity: CGFloat = 20
    static let particleBlurRadius: CGFloat = 2

    // MARK: - Gradient

    static let gradientPrimaryOpacity: Double = 0.3
    static let gradientSecondaryOpacity: Double = 0.2
    static let gradientTertiaryOpacity: Double = 0.1
    static let materialOpacityDark: Double = 0.3
    static let materialOpacityLight: Double = 0.1
    static let featureOverlayOpacity: Double = 0.2
    static let featureOverlaySecondaryOpacity: Double = 0.05
    static let gradientStartRadius: CGFloat = 100
    static let gradientEndRadius: CGFloat = 400

    // MARK: - Scale Effects

    static let glowScaleMax: CGFloat = 1.1
    static let glowScaleMin: CGFloat = 1.0
    static let buttonPressedScale: CGFloat = 0.95
    static let buttonNormalScale: CGFloat = 1.0
    static let buttonAnimationDuration: TimeInterval = 0.1

    // MARK: - Offsets

    static let animationOffset: CGFloat = 20
    static let featureAnimationOffset: CGFloat = 30

    // MARK: - Progress

    static let progressUpdateInterval: TimeInterval = 0.5
    static let progressUpdateNanoseconds: UInt64 = 500_000_000
    static let stateMonitorInterval: TimeInterval = 0.1
    static let stateMonitorNanoseconds: UInt64 = 100_000_000

    // MARK: - Other

    static let termsLineSpacing: CGFloat = 4
    static let termsHorizontalPadding: CGFloat = 40
    static let sheetMinWidth: CGFloat = 600
    static let sheetMinHeight: CGFloat = 400
    static let continueButtonMaxWidth: CGFloat = 300
    static let continueButtonHeight: CGFloat = 56
    static let continueButtonRadius: CGFloat = 28
    static let continueButtonShadowRadius: CGFloat = 10
    static let continueButtonShadowY: CGFloat = 5
    static let continueButtonSpacing: CGFloat = 12
    static let featureCarouselSpacing: CGFloat = 24
    static let featureCircleOpacity: Double = 0.1
    static let featureCircleScaleAnimated: CGFloat = 1.1
    static let featureCircleScaleDefault: CGFloat = 1.0
    static let featureCircleAnimationDuration: TimeInterval = 2
    static let featureTextSpacing: CGFloat = 12
    static let grayOpacity: Double = 0.8
    static let shadowOpacity: Double = 0.3
    static let featureRadialOpacityPrimary: Double = 0.2
    static let featureRadialOpacitySecondary: Double = 0.05
    static let defaultOpacity: Double = 0.5
    static let dotGrayOpacity: Double = 0.3
    static let backgroundOpacityPrimary: Double = 0.3
    static let backgroundOpacitySecondary: Double = 0.7
    static let progressViewOpacity: Double = 0.3
    static let animationTimeMultiplier: Double = 2
    static let nanosecondDivider: Int = 500_000_000
    static let delayMultiplierThree: Double = 3
    static let shadowYOffset: CGFloat = 5
    static let particleVelocityRange: ClosedRange<CGFloat> =
        CGFloat(particleMinVelocity) ... CGFloat(particleMaxVelocity)
    static let particleSizeRange: ClosedRange<CGFloat> = particleMinSize ... particleMaxSize
    static let particleOpacityRange: ClosedRange<Double> = particleMinOpacity ... particleMaxOpacity
    static let lineSpacingDivider: CGFloat = 2
}
