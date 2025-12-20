import Abstractions
import SwiftUI

/// The first onboarding screen that welcomes users to Think AI
internal struct OnboardingWelcomeView: View {
    // MARK: - Environment

    @Environment(\.appViewModel)
    private var appViewModel: AppViewModeling

    @Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    // MARK: - State

    @State private var animateGradient: Bool = false
    @State private var showContent: Bool = false
    @State private var particleSystem: ParticleSystem = .init()

    // MARK: - Body

    internal var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                animatedBackground

                // Floating particles
                ParticleView(system: particleSystem)
                    .allowsHitTesting(false)

                // Main content
                mainContent
            }
            .onAppear {
                withAnimation {
                    animateGradient = true
                    showContent = true
                }
                particleSystem.start(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var mainContent: some View {
        VStack(spacing: OnboardingConstants.sectionSpacing) {
            Spacer()

            animatedLogoSection
            animatedDescriptionSection

            Spacer()

            animatedContinueButton
        }
        .padding(.horizontal, OnboardingConstants.horizontalPadding)
        .padding(.vertical, OnboardingConstants.verticalPadding)
    }

    @ViewBuilder private var animatedLogoSection: some View {
        logoSection
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : OnboardingConstants.animationOffset)
            .animation(
                .easeOut(duration: OnboardingConstants.animationDuration)
                    .delay(OnboardingConstants.delayIncrement),
                value: showContent
            )
    }

    @ViewBuilder private var animatedDescriptionSection: some View {
        descriptionSection
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : OnboardingConstants.animationOffset)
            .animation(
                .easeOut(duration: OnboardingConstants.animationDuration)
                    .delay(
                        OnboardingConstants.delayIncrement
                            * OnboardingConstants.animationTimeMultiplier
                    ),
                value: showContent
            )
    }

    @ViewBuilder private var animatedContinueButton: some View {
        continueButton
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : OnboardingConstants.animationOffset)
            .animation(
                .easeOut(duration: OnboardingConstants.animationDuration)
                    .delay(
                        OnboardingConstants.delayIncrement
                            * OnboardingConstants.delayMultiplierThree
                    ),
                value: showContent
            )
    }

    @ViewBuilder private var animatedBackground: some View {
        AnimatedBackground(
            animateGradient: animateGradient,
            colorScheme: colorScheme
        )
    }

    @ViewBuilder private var logoSection: some View {
        VStack(spacing: OnboardingConstants.itemSpacing) {
            LogoView(animateGradient: animateGradient)
            TitleView()
        }
    }

    @ViewBuilder private var descriptionSection: some View {
        VStack(spacing: OnboardingConstants.largeSpacing) {
            Text("Your AI Assistant", bundle: .module)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text(
                // swiftlint:disable:next line_length
                "Experience the power of on-device AI with complete privacy and blazing-fast performance",
                bundle: .module
            )
            .font(.body)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(
                OnboardingConstants.smallSpacing / OnboardingConstants.lineSpacingDivider
            )
            .frame(maxWidth: OnboardingConstants.maxTextWidth)
        }
    }

    @ViewBuilder private var continueButton: some View {
        GetStartedButton {
            Task {
                await appViewModel.navigateToNextState()
            }
        }
    }
}

// MARK: - Animated Background

private struct AnimatedBackground: View {
    let animateGradient: Bool
    let colorScheme: ColorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color.marketingPrimary.opacity(OnboardingConstants.gradientPrimaryOpacity),
                Color.marketingSecondary.opacity(OnboardingConstants.gradientSecondaryOpacity),
                Color.marketingPrimary.opacity(OnboardingConstants.gradientTertiaryOpacity)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .animation(
            .linear(duration: OnboardingConstants.gradientAnimationDuration)
                .repeatForever(autoreverses: true),
            value: animateGradient
        )
        .overlay(
            // Subtle noise texture
            Rectangle()
                .fill(
                    .regularMaterial
                        .opacity(
                            colorScheme == .dark
                                ? OnboardingConstants.materialOpacityDark
                                : OnboardingConstants.materialOpacityLight
                        )
                )
                .ignoresSafeArea()
        )
    }
}

// MARK: - Get Started Button

private struct GetStartedButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: OnboardingConstants.mediumSpacing) {
                Text("Get Started", bundle: .module)
                    .font(.headline)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .foregroundColor(.white)
            .frame(maxWidth: OnboardingConstants.buttonMaxWidth)
            .frame(height: OnboardingConstants.buttonHeight)
            .background(
                LinearGradient(
                    colors: [.marketingPrimary, .marketingSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(OnboardingConstants.cornerRadius)
            .shadow(
                color: .marketingPrimary.opacity(OnboardingConstants.shadowOpacity),
                radius: OnboardingConstants.shadowRadius,
                y: OnboardingConstants.shadowYOffset
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        OnboardingWelcomeView()
            .environment(\.appViewModel, OnboardingPreviewAppViewModel())
    }

    /// Preview app view model
    private actor OnboardingPreviewAppViewModel: AppViewModeling {
        var appFlowState: AppFlowState { .onboardingWelcome }

        func initializeDatabase() {
            // Preview implementation - no-op
        }

        func setupInitialChat(with _: UUID) throws {
            // Preview implementation - no-op
        }

        func resumeBackgroundDownloads() {
            // Preview implementation - no-op
        }

        func navigateToNextState() {
            // Preview implementation - no-op
        }

        func completeOnboarding() {
            // Preview implementation - no-op
        }

        func requestNotificationPermissions() {
            // Preview implementation - no-op
        }

        func ensureDefaultModelExists() {
            // Preview implementation - no-op
        }
    }
#endif
