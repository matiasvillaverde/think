import SwiftUI

// MARK: - Feature Model

/// Model representing a feature to display in onboarding
public struct Feature: Sendable {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Feature Card

internal struct FeatureCard: View {
    let feature: Feature
    @State private var isAnimating: Bool = false

    var body: some View {
        VStack(spacing: OnboardingConstants.featureCarouselSpacing) {
            // Icon with animation
            FeatureIconView(feature: feature, isAnimating: isAnimating)

            // Text content
            FeatureTextContent(feature: feature)
        }
        .padding(.horizontal, OnboardingConstants.termsHorizontalPadding)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Terms Acceptance View

internal struct TermsAcceptanceView: View {
    @Binding var termsAccepted: Bool
    @Binding var showTermsOfService: Bool
    @Binding var showPrivacyPolicy: Bool
    let onContinue: () -> Void

    internal init(
        termsAccepted: Binding<Bool>,
        showTermsOfService: Binding<Bool>,
        showPrivacyPolicy: Binding<Bool>,
        onContinue: @escaping () -> Void
    ) {
        _termsAccepted = termsAccepted
        _showTermsOfService = showTermsOfService
        _showPrivacyPolicy = showPrivacyPolicy
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: OnboardingConstants.itemSpacing) {
            // Terms checkbox
            HStack(spacing: OnboardingConstants.mediumSpacing) {
                Button {
                    withAnimation(
                        .easeInOut(duration: OnboardingConstants.shortAnimationDuration)
                    ) {
                        termsAccepted.toggle()
                    }
                } label: {
                    Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundColor(termsAccepted ? .marketingPrimary : .gray)
                        .accessibilityLabel(
                            termsAccepted ? "Terms accepted" : "Terms not accepted"
                        )
                }
                .buttonStyle(PlainButtonStyle())

                TermsTextView(
                    showTermsOfService: $showTermsOfService,
                    showPrivacyPolicy: $showPrivacyPolicy
                )
            }
            .padding(.horizontal, OnboardingConstants.termsHorizontalPadding)

            // Continue button
            ContinueButton(termsAccepted: termsAccepted, onContinue: onContinue)
        }
        .padding(.bottom, OnboardingConstants.largeSpacing + OnboardingConstants.termsLineSpacing)
    }
}

// MARK: - Terms Text View

internal struct TermsTextView: View {
    @Binding var showTermsOfService: Bool
    @Binding var showPrivacyPolicy: Bool

    var body: some View {
        HStack(spacing: OnboardingConstants.termsLineSpacing) {
            Text("I agree to the", bundle: .module)
                .foregroundColor(.textSecondary)

            Button {
                showTermsOfService = true
            } label: {
                Text("Terms of Service", bundle: .module)
                    .foregroundColor(.marketingPrimary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())

            Text("and", bundle: .module)
                .foregroundColor(.textSecondary)

            Button {
                showPrivacyPolicy = true
            } label: {
                Text("Privacy Policy", bundle: .module)
                    .foregroundColor(.marketingPrimary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .font(.footnote)
    }
}

// MARK: - Feature Carousel View

internal struct FeatureCarouselView: View {
    @Binding var selectedFeatureIndex: Int
    let features: [Feature]

    var body: some View {
        VStack(spacing: OnboardingConstants.horizontalPadding) {
            // Feature dots indicator
            HStack(spacing: OnboardingConstants.smallSpacing) {
                ForEach(0 ..< features.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == selectedFeatureIndex
                                ? Color.marketingPrimary
                                : Color.gray.opacity(OnboardingConstants.dotGrayOpacity)
                        )
                        .frame(
                            width: OnboardingConstants.featureDotSize,
                            height: OnboardingConstants.featureDotSize
                        )
                        .animation(.easeInOut, value: selectedFeatureIndex)
                }
            }

            // Feature display
            TabView(selection: $selectedFeatureIndex) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    FeatureCard(feature: feature)
                        .tag(index)
                }
            }
            .frame(height: OnboardingConstants.featureCardHeight)
            #if os(iOS) || os(visionOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            #else
                .tabViewStyle(.automatic)
            #endif
        }
    }
}

// MARK: - Feature Icon View

internal struct FeatureIconView: View {
    let feature: Feature
    let isAnimating: Bool

    var body: some View {
        ZStack {
            FeatureBackgroundCircle(feature: feature, isAnimating: isAnimating)
            FeatureIcon(feature: feature)
        }
    }
}

// MARK: - Feature Background Circle

internal struct FeatureBackgroundCircle: View {
    let feature: Feature
    let isAnimating: Bool

    var body: some View {
        Circle()
            .fill(feature.color.opacity(OnboardingConstants.featureCircleOpacity))
            .frame(
                width: OnboardingConstants.featureCircleSize,
                height: OnboardingConstants.featureCircleSize
            )
            .scaleEffect(
                isAnimating
                    ? OnboardingConstants.featureCircleScaleAnimated
                    : OnboardingConstants.featureCircleScaleDefault
            )
            .animation(
                .easeInOut(duration: OnboardingConstants.featureCircleAnimationDuration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
    }
}

// MARK: - Feature Icon

internal struct FeatureIcon: View {
    let feature: Feature

    var body: some View {
        Image(systemName: feature.icon)
            .font(.system(size: OnboardingConstants.featureIconSize))
            .accessibilityHidden(true)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        feature.color,
                        feature.color.opacity(
                            OnboardingConstants.backgroundOpacitySecondary
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Feature Text Content

internal struct FeatureTextContent: View {
    let feature: Feature

    var body: some View {
        VStack(spacing: OnboardingConstants.featureTextSpacing) {
            Text(feature.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(feature.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(OnboardingConstants.termsLineSpacing)
                .frame(maxWidth: OnboardingConstants.featureMaxTextWidth)
        }
    }
}

// MARK: - Continue Button

internal struct ContinueButton: View {
    let termsAccepted: Bool
    let onContinue: () -> Void

    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: OnboardingConstants.continueButtonSpacing) {
                Text("Continue", bundle: .module)
                    .font(.headline)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .foregroundColor(.white)
            .frame(maxWidth: OnboardingConstants.continueButtonMaxWidth)
            .frame(height: OnboardingConstants.continueButtonHeight)
            .background(
                LinearGradient(
                    colors: termsAccepted
                        ? [.marketingPrimary, .marketingSecondary]
                        : [.gray, .gray.opacity(OnboardingConstants.grayOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(OnboardingConstants.continueButtonRadius)
            .shadow(
                color: termsAccepted
                    ? .marketingPrimary.opacity(OnboardingConstants.shadowOpacity)
                    : .clear,
                radius: OnboardingConstants.continueButtonShadowRadius,
                y: OnboardingConstants.continueButtonShadowY
            )
        }
        .disabled(!termsAccepted)
        .buttonStyle(ScaleButtonStyle())
    }
}
