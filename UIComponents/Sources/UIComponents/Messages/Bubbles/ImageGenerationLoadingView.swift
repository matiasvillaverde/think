import Combine
import SwiftUI

/// A view that displays an animated "Generating Image..." indicator
public struct ImageGenerationLoadingView: View {
    // MARK: - Constants

    private enum Constants {
        static let horizontalSpacing: CGFloat = 12
        static let verticalPadding: CGFloat = 4
        static let iconSize: CGFloat = 14
        static let phraseRefreshInterval: TimeInterval = 3.5
        static let phaseTransitionDuration: TimeInterval = 0.6
        static let letterAnimationDuration: TimeInterval = 0.4
        static let letterDelayMultiplier: TimeInterval = 0.04
        static let dotSpacing: CGFloat = 2
        static let dotSize: CGFloat = 4
        static let dotAnimationDuration: TimeInterval = 0.6
        static let dotAnimationBaseDelay: TimeInterval = 1.2
        static let dotAnimationDelayMultiplier: TimeInterval = 0.2
        static let dotsLeadingPadding: CGFloat = 4
        static let inactiveOpacity: Double = 0.5
        static let inactiveScale: CGFloat = 0.8
        static let numberOfDots: Int = 3
        static let gradientStartFraction: CGFloat = 0.0
        static let gradientEndFraction: CGFloat = 0.5
        static let colorOpacity: Double = 0.7
    }

    // MARK: - Properties

    @State private var currentPhraseIndex: Int = 0
    @State private var isAnimating: Bool = false

    private let timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(
        every: Constants.phraseRefreshInterval,
        on: .main,
        in: .common
    )
    .autoconnect()

    private static let phrases: [String] = [
        String(localized: "Generating Image", bundle: .module),
        String(localized: "Creating Visual", bundle: .module),
        String(localized: "Processing Image", bundle: .module)
    ]

    // MARK: - Body

    public var body: some View {
        HStack(spacing: Constants.horizontalSpacing) {
            animatedSparklesIcon
            animatedPhrase
        }
        .padding(.vertical, Constants.verticalPadding)
        .onAppear {
            isAnimating = true
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: Constants.phaseTransitionDuration)) {
                currentPhraseIndex = (currentPhraseIndex + 1) % Self.phrases.count
            }
        }
    }

    // MARK: - Private Views

    private var animatedSparklesIcon: some View {
        Image(systemName: "photo.on.rectangle.angled.fill")
            .font(.title2)
            .foregroundStyle(
                EllipticalGradient(
                    colors: [Color.marketingPrimary, Color.marketingPrimary],
                    center: .center,
                    startRadiusFraction: Constants.gradientStartFraction,
                    endRadiusFraction: Constants.gradientEndFraction
                )
            )
            .symbolEffect(
                .pulse.byLayer,
                options: .speed(1).repeating,
                value: isAnimating
            )
            .symbolEffect(
                .bounce.down.byLayer,
                options: .speed(1).repeating,
                value: isAnimating
            )
            .accessibilityHidden(true)
    }

    private var animatedPhrase: some View {
        HStack(spacing: 0) {
            phraseLetters
            animatedDots
        }
    }

    private var phraseLetters: some View {
        ForEach(
            Array(Self.phrases[currentPhraseIndex].enumerated()),
            id: \.offset
        ) { index, letter in
            Text(String(letter))
                .font(.headline)
                .bold()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.marketingPrimary,
                            Color.marketingPrimary.opacity(Constants.colorOpacity)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(isAnimating ? 1 : Constants.inactiveOpacity)
                .scaleEffect(isAnimating ? 1 : Constants.inactiveScale)
                .animation(
                    .easeInOut(duration: Constants.letterAnimationDuration)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * Constants.letterDelayMultiplier),
                    value: isAnimating
                )
        }
    }

    private var animatedDots: some View {
        HStack(spacing: Constants.dotSpacing) {
            ForEach(0 ..< Constants.numberOfDots, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.marketingPrimary,
                                Color.marketingPrimary.opacity(
                                    Constants.colorOpacity
                                )
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: Constants.dotSize, height: Constants.dotSize)
                    .opacity(isAnimating ? 1 : 0)
                    .scaleEffect(isAnimating ? 1 : Constants.inactiveScale)
                    .animation(
                        .easeInOut(duration: Constants.dotAnimationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(
                                Constants.dotAnimationBaseDelay + Double(index)
                                    * Constants.dotAnimationDelayMultiplier
                            ),
                        value: isAnimating
                    )
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, Constants.dotsLeadingPadding)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack {
            ImageGenerationLoadingView()
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(8)

            ImageGenerationLoadingView()
                .padding()
                .background(Color.backgroundPrimary)
                .cornerRadius(8)
                .preferredColorScheme(.dark)
        }
        .padding()
    }
#endif
