import SwiftUI

// MARK: - Particle System

/// Simple particle system for background animation
public struct ParticleSystem {
    /// Array of particles in the system
    public var particles: [Particle] = []

    /// Creates a new particle system
    public init() {
        // Empty initialization - particles are created on start()
    }

    /// Starts the particle system by creating random particles
    /// - Parameters:
    ///   - width: The width of the container
    ///   - height: The height of the container
    public mutating func start(width: CGFloat = 1_000, height: CGFloat = 1_000) {
        particles = (0 ..< OnboardingConstants.particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0 ... width),
                    y: CGFloat.random(in: 0 ... height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: OnboardingConstants.particleVelocityRange),
                    dy: CGFloat.random(in: OnboardingConstants.particleVelocityRange)
                ),
                size: CGFloat.random(in: OnboardingConstants.particleSizeRange),
                opacity: Double.random(in: OnboardingConstants.particleOpacityRange)
            )
        }
    }
}

public struct Particle: Identifiable {
    public let id: UUID = .init()
    public var position: CGPoint
    public var velocity: CGVector
    public var size: CGFloat
    public var opacity: Double
}

internal struct ParticleView: View {
    let system: ParticleSystem

    var body: some View {
        ZStack {
            ForEach(system.particles) { particle in
                Circle()
                    .fill(Color.marketingPrimary.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: OnboardingConstants.particleBlurRadius)
            }
        }
    }
}

// MARK: - Logo View

internal struct LogoView: View {
    let animateGradient: Bool

    var body: some View {
        ZStack {
            LogoGlowRing(animateGradient: animateGradient)
            LogoImage()
        }
        .scaleEffect(
            animateGradient
                ? OnboardingConstants.glowScaleMax
                : OnboardingConstants.glowScaleMin
        )
        .animation(
            .easeInOut(duration: OnboardingConstants.particleAnimationDuration)
                .repeatForever(autoreverses: true),
            value: animateGradient
        )
    }
}

// MARK: - Logo Glow Ring

internal struct LogoGlowRing: View {
    let animateGradient: Bool

    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.marketingPrimary, .marketingSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: OnboardingConstants.lineWidth
            )
            .frame(
                width: OnboardingConstants.logoRingSize,
                height: OnboardingConstants.logoRingSize
            )
            .shadow(
                color: .marketingPrimary.opacity(OnboardingConstants.defaultOpacity),
                radius: OnboardingConstants.glowRadius
            )
    }
}

// MARK: - Logo Image

internal struct LogoImage: View {
    var body: some View {
        Image(ImageResource(name: "think", bundle: .module))
            .resizable()
            .scaledToFit()
            .frame(
                width: OnboardingConstants.logoSize,
                height: OnboardingConstants.logoSize
            )
            .clipShape(Circle())
            .shadow(
                color: .marketingPrimary.opacity(OnboardingConstants.shadowOpacity),
                radius: OnboardingConstants.shadowRadius
            )
            .accessibilityLabel("Think AI Logo")
    }
}

// MARK: - Title View

internal struct TitleView: View {
    var body: some View {
        VStack(spacing: OnboardingConstants.smallSpacing) {
            Text("Welcome to", bundle: .module)
                .font(.title2)
                .foregroundColor(.textSecondary)

            Text("Think AI", bundle: .module)
                .font(
                    .system(
                        size: OnboardingConstants.titleFontSize,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.marketingPrimary, .marketingSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Button Style

public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? OnboardingConstants.buttonPressedScale
                    : OnboardingConstants.buttonNormalScale
            )
            .animation(
                .easeInOut(duration: OnboardingConstants.buttonAnimationDuration),
                value: configuration.isPressed
            )
    }
}
