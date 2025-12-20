import SwiftUI

// swiftlint:disable explicit_type_interface
// swiftlint:disable function_parameter_count

/// Constants used throughout the fluid animation
internal enum VoiceAnimationConstants {
    /// Layout constants
    enum Layout {
        /// Horizontal center multiplier (0.5)
        static let horizontalCenterMultiplier: Double = 0.5
    }

    /// Color-related constants
    enum Color {
        /// Base hue value for gradients
        static let baseHue: Double = 0.6 // Assuming this value from original
        /// Hue variation between layers
        static let hueDelta: Double = 0.1 // Assuming this value from original
        /// Base saturation value for colors
        static let baseSaturation: Double = 0.8 // Assuming this value from original
        /// First saturation delta amount
        static let saturationDelta1: Double = 0.2 // Assuming this value from original
        /// Second saturation delta amount
        static let saturationDelta2: Double = 0.1 // Assuming this value from original
        /// Base brightness value
        static let baseBrightness: Double = 1.0 // Assuming this value from original
        /// Brightness delta between layers
        static let brightnessDelta: Double = 0.1 // Assuming this value from original
        /// First opacity delta value
        static let baseOpacityDelta1: Double = 0.3 // Assuming this value from original
        /// Second opacity delta value
        static let baseOpacityDelta2: Double = 0.2 // Assuming this value from original
        /// Hue offset for bottom color
        static let bottomColorHueOffset: Double = 0.05
        /// Saturation offset for bottom color
        static let bottomColorSaturationOffset: Double = 0.3
        /// Brightness offset for bottom color
        static let bottomColorBrightnessOffset: Double = 0.1
    }

    /// Fluid effect animation constants
    enum FluidEffect {
        /// Number of wave layers
        static let layerCount: Int = 5 // Assuming this value from original
        /// Base time multiplier
        static let baseTimeMultiplier: Double = 1.0 // Assuming this value from original
        /// Layer time multiplier delta
        static let layerTimeMultiplierDelta: Double = 0.2 // Assuming this value from original
        /// Height multiplier for layers
        static let heightMultiplier: Double = 0.15 // Assuming this value from original
        /// Base amplitude for waves
        static let baseAmplitude: Double = 30.0 // Assuming this value from original
        /// Amplitude delta between layers
        static let amplitudeLayerDelta: Double = 10.0 // Assuming this value from original
        /// Base frequency for waves
        static let baseFrequency: Double = 2.0 // Assuming this value from original
        /// Frequency delta between layers
        static let frequencyLayerDelta: Double = 0.3 // Assuming this value from original
        /// First wave time multiplier
        static let waveTimeMultiplier1: Double = 2.0 // Assuming this value from original
        /// Second wave time multiplier
        static let waveTimeMultiplier2: Double = 1.5 // Assuming this value from original
        /// Frequency divider for second wave
        static let frequencyDivider: Double = 0.5 // Assuming this value from original
        /// Base vertical position for waves
        static let baseVerticalPosition: Double = 0.7 // Assuming this value from original
        /// Dynamic amplitude base value
        static let dynamicAmplitudeBase: Double = 0.8 // Assuming this value from original
        /// Dynamic amplitude variation amount
        static let dynamicAmplitudeVariation: Double = 0.2 // Assuming this value from original
        /// Gradient start Y offset
        static let gradientStartOffsetY: Double = 0.2 // Assuming this value from original
        /// Y offset multiplier for waves
        static let yOffsetMultiplier: Double = 0.5
        /// Step size for wave pattern generation
        static let wavePatternStepSize: CGFloat = 1
    }
}

/// Metal-based fluid animation view
internal struct FluidAnimationView: View {
    // MARK: - Properties

    /// Animation speed multiplier
    let speed: Double

    /// Animation intensity (opacity)
    let intensity: Double

    /// Current animation time
    @State private var time: Double = 0

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            // Update time based on the current date
            let newTime: TimeInterval = timeline.date.timeIntervalSince1970 * speed

            // Use Canvas for high-performance drawing
            Canvas { context, size in
                // Draw the fluid effect
                drawFluidEffect(in: context, size: size, time: newTime, intensity: intensity)
            }
            .onChange(of: timeline.date) { _, _ in
                time = newTime
            }
            .drawingGroup() // Use Metal renderer for better performance
        }
    }

    // MARK: - Private Methods

    /// Draws the complete fluid effect with multiple wave layers
    private func drawFluidEffect(
        in context: GraphicsContext,
        size: CGSize,
        time: Double,
        intensity: Double
    ) {
        // Create multiple wave layers with different properties
        let layerCount = VoiceAnimationConstants.FluidEffect.layerCount

        for layerIndex in 0 ..< layerCount {
            let normalizedLayer = calculateNormalizedLayer(
                layerIndex: layerIndex,
                count: layerCount
            )
            let adjustedTime = calculateAdjustedTime(time: time, normalizedLayer: normalizedLayer)
            let verticalOffset = calculateVerticalOffset(
                normalizedLayer: normalizedLayer,
                size: size
            )

            // Create gradient for this layer
            let gradient = createGradient(normalizedLayer: normalizedLayer, intensity: intensity)

            // Draw wave path for this layer
            let path = createWavePath(
                size: size,
                time: time,
                adjustedTime: adjustedTime,
                normalizedLayer: normalizedLayer,
                verticalOffset: verticalOffset
            )

            // Fill with gradient
            fillPathWithGradient(
                context: context,
                path: path,
                gradient: gradient,
                size: size,
                verticalOffset: verticalOffset
            )
        }
    }

    /// Calculates normalized layer value (0-1)
    private func calculateNormalizedLayer(layerIndex: Int, count: Int) -> Double {
        Double(layerIndex) / Double(count - 1)
    }

    /// Calculates time adjusted for the specific layer
    private func calculateAdjustedTime(time: Double, normalizedLayer: Double) -> Double {
        time * (
            VoiceAnimationConstants.FluidEffect.baseTimeMultiplier +
                normalizedLayer * VoiceAnimationConstants.FluidEffect.layerTimeMultiplierDelta
        )
    }

    /// Calculates vertical offset for a layer
    private func calculateVerticalOffset(normalizedLayer: Double, size: CGSize) -> Double {
        normalizedLayer * size.height * VoiceAnimationConstants.FluidEffect.heightMultiplier
    }

    /// Creates color gradient for a layer
    private func createGradient(normalizedLayer: Double, intensity: Double) -> Gradient {
        let topColor = createTopColor(normalizedLayer: normalizedLayer, intensity: intensity)
        let bottomColor = createBottomColor(normalizedLayer: normalizedLayer, intensity: intensity)
        return Gradient(colors: [topColor, bottomColor])
    }

    /// Creates top color for the gradient
    private func createTopColor(normalizedLayer: Double, intensity: Double) -> Color {
        let constants = VoiceAnimationConstants.Color.self

        let hue = constants.baseHue + normalizedLayer * constants.hueDelta
        let saturation = constants.baseSaturation - normalizedLayer * constants.saturationDelta1
        let brightness = constants.baseBrightness
        let opacity = (1.0 - normalizedLayer * constants.baseOpacityDelta1) * intensity

        return Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness
        ).opacity(opacity)
    }

    /// Creates bottom color for the gradient
    private func createBottomColor(normalizedLayer: Double, intensity: Double) -> Color {
        let constants = VoiceAnimationConstants.Color.self

        let hue = constants.baseHue + constants.bottomColorHueOffset +
            normalizedLayer * constants.hueDelta
        let saturation = constants.baseSaturation + constants.bottomColorSaturationOffset -
            normalizedLayer * constants.saturationDelta2
        let brightness = constants.baseBrightness - constants.bottomColorBrightnessOffset -
            normalizedLayer * constants.brightnessDelta
        let opacity = (1.0 - normalizedLayer * constants.baseOpacityDelta2) * intensity

        return Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness
        ).opacity(opacity)
    }

    /// Creates a wave path for a layer
    private func createWavePath(
        size: CGSize,
        time: Double,
        adjustedTime: Double,
        normalizedLayer: Double,
        verticalOffset: Double
    ) -> Path {
        let constants = VoiceAnimationConstants.FluidEffect.self

        let amplitude = constants.baseAmplitude -
            normalizedLayer * constants.amplitudeLayerDelta
        let frequency = constants.baseFrequency +
            normalizedLayer * constants.frequencyLayerDelta

        var path = Path()
        // Start at bottom left
        path.move(to: CGPoint(x: 0, y: size.height))

        // Create wave pattern
        createWavePattern(
            in: &path,
            size: size,
            time: time,
            adjustedTime: adjustedTime,
            amplitude: amplitude,
            frequency: frequency,
            verticalOffset: verticalOffset
        )

        // Complete the path
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()

        return path
    }

    /// Creates the wave pattern points
    private func createWavePattern(
        in path: inout Path,
        size: CGSize,
        time: Double,
        adjustedTime: Double,
        amplitude: Double,
        frequency: Double,
        verticalOffset: Double
    ) {
        let constants = VoiceAnimationConstants.FluidEffect.self

        for positionX in stride(from: 0, through: size.width, by: constants.wavePatternStepSize) {
            let progress = positionX / size.width

            let xOffset = calculateXOffset(
                progress: progress,
                frequency: frequency,
                adjustedTime: adjustedTime
            )

            let yOffset = calculateYOffset(
                progress: progress,
                frequency: frequency,
                adjustedTime: adjustedTime
            )

            let normalizedX = positionX / size.width
            let baseY = size.height * constants.baseVerticalPosition

            let dynamicAmplitude = calculateDynamicAmplitude(
                amplitude: amplitude,
                normalizedX: normalizedX,
                time: time
            )

            let positionY = baseY +
                xOffset * dynamicAmplitude +
                yOffset * dynamicAmplitude * constants.yOffsetMultiplier +
                verticalOffset

            path.addLine(to: CGPoint(x: positionX, y: positionY))
        }
    }

    /// Calculates X offset for wave pattern
    private func calculateXOffset(
        progress: CGFloat,
        frequency: Double,
        adjustedTime: Double
    ) -> Double {
        sin(
            Double(progress) * .pi * frequency +
                adjustedTime * VoiceAnimationConstants.FluidEffect.waveTimeMultiplier1
        )
    }

    /// Calculates Y offset for wave pattern
    private func calculateYOffset(
        progress: CGFloat,
        frequency: Double,
        adjustedTime: Double
    ) -> Double {
        cos(
            Double(progress) * .pi
                * (frequency * VoiceAnimationConstants.FluidEffect.frequencyDivider) +
                adjustedTime * VoiceAnimationConstants.FluidEffect.waveTimeMultiplier2
        )
    }

    /// Calculates dynamic amplitude based on position
    private func calculateDynamicAmplitude(
        amplitude: Double,
        normalizedX: CGFloat,
        time: Double
    ) -> Double {
        let constants = VoiceAnimationConstants.FluidEffect.self

        return amplitude * (
            constants.dynamicAmplitudeBase +
                sin(Double(normalizedX) * .pi + time) * constants.dynamicAmplitudeVariation
        )
    }

    /// Fills the path with a gradient
    private func fillPathWithGradient(
        context: GraphicsContext,
        path: Path,
        gradient: Gradient,
        size: CGSize,
        verticalOffset: Double
    ) {
        let horizontalCenter = size.width
            * VoiceAnimationConstants.Layout.horizontalCenterMultiplier

        let startPoint = CGPoint(
            x: horizontalCenter,
            y: size.height
                * VoiceAnimationConstants.FluidEffect.gradientStartOffsetY + verticalOffset
        )

        let endPoint = CGPoint(
            x: horizontalCenter,
            y: size.height
        )

        context.fill(
            path,
            with: .linearGradient(
                gradient,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
}

// swiftlint:enable explicit_type_interface
// swiftlint:enable function_parameter_count
