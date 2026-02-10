import Abstractions
import Combine
import SwiftUI

/// The second onboarding screen that showcases key features
internal struct OnboardingFeaturesView: View {
    // MARK: - Environment

    @Environment(\.appViewModel)
    private var appViewModel: AppViewModeling

    @Environment(\.onboardingCoordinator)
    private var onboardingCoordinator: OnboardingCoordinating?

    @Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    // MARK: - State

    @State private var selectedFeatureIndex: Int = 0
    @State private var showContent: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var termsAccepted: Bool = false
    @State private var showTermsOfService: Bool = false
    @State private var showPrivacyPolicy: Bool = false

    // MARK: - Properties

    private let features: [Feature] = OnboardingFeatures.all

    private let timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer
        .publish(
            every: OnboardingConstants.featureRotationInterval,
            on: .main,
            in: .common
        )
        .autoconnect()

    // MARK: - Body

    internal var body: some View {
        ZStack {
            // Background
            backgroundGradient

            VStack(spacing: 0) {
                // Header with progress
                headerSection

                // Feature carousel
                featureCarousel
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : OnboardingConstants.featureAnimationOffset)
                    .animation(
                        .easeOut(duration: OnboardingConstants.animationDuration)
                            .delay(OnboardingConstants.delayIncrement),
                        value: showContent
                    )

                Spacer()

                // Terms and continue section
                bottomSection
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : OnboardingConstants.featureAnimationOffset)
                    .animation(
                        .easeOut(duration: OnboardingConstants.animationDuration)
                            .delay(
                                OnboardingConstants.delayIncrement
                                    * OnboardingConstants.animationTimeMultiplier
                            ),
                        value: showContent
                    )
            }
            .padding(.vertical, OnboardingConstants.horizontalPadding)
        }
        .onAppear {
            withAnimation {
                showContent = true
            }
        }
        .task {
            // Monitor download progress
            await updateDownloadProgress()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: OnboardingConstants.featureTransitionDuration)) {
                selectedFeatureIndex = (selectedFeatureIndex + 1) % features.count
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            termsSheetContent()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            privacySheetContent()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func termsSheetContent() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                TermsOfUseView()
                    .navigationTitle(Text("Terms of Service", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done", bundle: .module)) {
                                showTermsOfService = false
                            }
                        }
                    }
            }
        #else
            TermsOfUseView()
                .frame(
                    minWidth: OnboardingConstants.sheetMinWidth,
                    minHeight: OnboardingConstants.sheetMinHeight
                )
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(String(localized: "Done", bundle: .module)) {
                            showTermsOfService = false
                        }
                    }
                }
        #endif
    }

    @ViewBuilder
    private func privacySheetContent() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                PrivacyPolicyView()
                    .navigationTitle(Text("Privacy Policy", bundle: .module))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done", bundle: .module)) {
                                showPrivacyPolicy = false
                            }
                        }
                    }
            }
        #else
            PrivacyPolicyView()
                .frame(
                    minWidth: OnboardingConstants.sheetMinWidth,
                    minHeight: OnboardingConstants.sheetMinHeight
                )
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(String(localized: "Done", bundle: .module)) {
                            showPrivacyPolicy = false
                        }
                    }
                }
        #endif
    }

    @ViewBuilder private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.backgroundPrimary,
                    Color.backgroundSecondary.opacity(OnboardingConstants.defaultOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Feature color overlay
            RadialGradient(
                colors: [
                    features[selectedFeatureIndex].color.opacity(
                        OnboardingConstants.featureRadialOpacityPrimary
                    ),
                    features[selectedFeatureIndex].color.opacity(
                        OnboardingConstants.featureRadialOpacitySecondary
                    ),
                    Color.paletteClear
                ],
                center: .center,
                startRadius: OnboardingConstants.gradientStartRadius,
                endRadius: OnboardingConstants.gradientEndRadius
            )
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: OnboardingConstants.featureCircleScaleDefault),
                value: selectedFeatureIndex
            )
        }
    }

    @ViewBuilder private var headerSection: some View {
        VStack(spacing: OnboardingConstants.itemSpacing) {
            // Title
            Text("Your Personal Team", bundle: .module)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(
                """
                Run OpenClaw locally out of the box. Use MLX or Llama.cpp models, or connect to a
                remote OpenClaw. Hosted models: one click, coming soon.
                """,
                bundle: .module
            )
            .font(.callout)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: OnboardingConstants.maxTextWidth)

            // Download progress indicator
            if downloadProgress > 0, downloadProgress < 1 {
                VStack(spacing: OnboardingConstants.smallSpacing) {
                    Text("Preparing models in background...", bundle: .module)
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .marketingPrimary))
                        .frame(maxWidth: OnboardingConstants.progressMaxWidth)
                }
                .padding(.horizontal, OnboardingConstants.horizontalPadding)
            }
        }
        .padding(.horizontal, OnboardingConstants.horizontalPadding)
        .padding(.bottom, OnboardingConstants.horizontalPadding)
    }

    @ViewBuilder private var featureCarousel: some View {
        FeatureCarouselView(
            selectedFeatureIndex: $selectedFeatureIndex,
            features: features
        )
    }

    @ViewBuilder private var bottomSection: some View {
        TermsAcceptanceView(
            termsAccepted: $termsAccepted,
            showTermsOfService: $showTermsOfService,
            showPrivacyPolicy: $showPrivacyPolicy
        ) {
            Task {
                await appViewModel.navigateToNextState()
            }
        }
    }

    // MARK: - Methods

    private func updateDownloadProgress() async {
        guard let coordinator = onboardingCoordinator else {
            return
        }

        // Monitor download progress from OnboardingCoordinator
        while true {
            let progress: Double = await coordinator.overallProgress
            await MainActor.run {
                downloadProgress = progress
            }

            if await coordinator.isDownloadComplete {
                break
            }

            try? await Task.sleep(
                nanoseconds: UInt64(OnboardingConstants.nanosecondDivider)
            )
        }
    }
}

// MARK: - Onboarding Features

private enum OnboardingFeatures {
    static let all: [Feature] = [
        Feature(
            icon: "bolt.fill",
            title: String(localized: "Local OpenClaw (Ready now)", bundle: .module),
            description: String(
                localized: "Start instantly with a built-in OpenClaw on your device.",
                bundle: .module
            ),
            color: .blue
        ),
        Feature(
            icon: "cpu",
            title: String(localized: "Local models (MLX or Llama.cpp)", bundle: .module),
            description: String(
                localized: "Fast, private inference on-device with MLX or llama.cpp.",
                bundle: .module
            ),
            color: .green
        ),
        Feature(
            icon: "link",
            title: String(localized: "Connect to OpenClaw", bundle: .module),
            description: String(
                localized: "Link to a remote OpenClaw instance to use its models and capabilities.",
                bundle: .module
            ),
            color: .orange
        ),
        Feature(
            icon: "cloud.fill",
            title: String(localized: "Hosted models (Coming soon)", bundle: .module),
            description: String(
                localized: "One-click hosted models, no setup.",
                bundle: .module
            ),
            color: .purple
        )
    ]
}

// MARK: - Preview

#if DEBUG
    #Preview {
        OnboardingFeaturesView()
            .environment(\.appViewModel, FeaturesPreviewAppViewModel())
            .environment(\.onboardingCoordinator, nil as OnboardingCoordinating?)
    }

    /// Preview app view model
    private actor FeaturesPreviewAppViewModel: AppViewModeling {
        var appFlowState: AppFlowState { .onboardingFeatures }

        func initializeDatabase() {
            // Preview implementation - no-op
        }

        func setupInitialChat(with _: UUID) {
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
