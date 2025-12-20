import Combine
import MetalKit
import SwiftUI

// MARK: - Constants

/// LayoutVoice constants
public enum LayoutVoice {
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 40
    }

    enum Size {
        static let circleButton: CGFloat = 60
        static let circleButtonFont: CGFloat = 22 // ~= .title2
        static let circleView: CGFloat = 210
    }

    enum Edge {
        static let bottom: CGFloat = 40
    }
}

/// Animation constants
internal enum AnimationConstants {
    enum FluidEffect {
        static let layerCount: Int = 4
        static let baseTimeMultiplier: Double = 0.5
        static let layerTimeMultiplierDelta: Double = 0.3
        static let baseAmplitude: Double = 15.0
        static let amplitudeLayerDelta: Double = 5.0
        static let baseFrequency: Double = 8.0
        static let frequencyLayerDelta: Double = 4.0
        static let heightMultiplier: Double = 0.6
        static let waveTimeMultiplier1: Double = 2.0
        static let waveTimeMultiplier2: Double = 3.0
        static let frequencyDivider: Double = 0.5
        static let dynamicAmplitudeBase: Double = 0.8
        static let dynamicAmplitudeVariation: Double = 0.2
        static let baseVerticalPosition: Double = 0.5
        static let gradientStartOffsetY: Double = 0.3
        static let animationSpeed: Double = 1.0
        static let colorIntensity: Double = 0.4
    }

    enum Color {
        static let baseHue: Double = 0.55
        static let hueDelta: Double = 0.05
        static let baseSaturation: Double = 0.5
        static let saturationDelta1: Double = 0.3
        static let saturationDelta2: Double = 0.2
        static let baseBrightness: Double = 1.0
        static let brightnessDelta: Double = 0.3
        static let baseOpacityDelta1: Double = 0.3
        static let baseOpacityDelta2: Double = 0.2
    }
}

/// Style constants
internal enum StyleConstants {
    enum Opacity {
        static let borderOverlay: Double = 0.15
        static let shadowEffect: Double = 0.3
        static let buttonShadow: Double = 0.2
    }

    enum Shadow {
        static let radius: CGFloat = 20
        static let buttonRadius: CGFloat = 5
        static let offset: CGFloat = 0
        static let buttonOffsetY: CGFloat = 2
    }

    enum Border {
        static let width: CGFloat = 1
    }
}
