import Abstractions
import SkeletonUI
import SwiftUI

/// A welcome view shown to first-time users for selecting their initial language model
public struct WelcomeView: View {
    // MARK: - Environment

    @Environment(\.discoveryCarousel)
    private var viewModel: DiscoveryCarouselViewModeling

    // MARK: - State

    @State private var recommendedModels: [DiscoveredModel] = []
    @State private var isLoadingRecommended: Bool = true
    @State private var recommendedError: Error?
    @State private var selectedModelId: String?
    @State private var isSavingModel: Bool = false
    @State private var saveError: Error?
    @State private var loadAttempts: Int = 0

    // MARK: - Properties

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    private let onModelSelected: (UUID) -> Void

    // MARK: - Initialization

    public init(onModelSelected: @escaping (UUID) -> Void) {
        self.onModelSelected = onModelSelected
    }

    // MARK: - Computed Properties

    private var languageModels: [DiscoveredModel] {
        recommendedModels.filter { model in
            // Use the inferredModelType for more robust detection
            if let modelType = model.inferredModelType {
                switch modelType {
                case .language, .deepLanguage, .flexibleThinker:
                    return true

                case .diffusion, .diffusionXL, .visualLanguage:
                    return false
                }
            }

            // Fallback to tag-based detection if inferredModelType is nil
            return model.tags.contains { tag in
                let lowercased: String = tag.lowercased()
                return lowercased.contains("text-generation") ||
                    lowercased.contains("language-model") ||
                    lowercased.contains("llm") ||
                    lowercased.contains("conversational") ||
                    lowercased.contains("chat")
            }
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            headerSection

            modelSelectionContent

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .task {
            await loadRecommendedModels()
        }
        .alert(
            "Error",
            isPresented: .constant(saveError != nil),
            presenting: saveError
        ) { _ in
            Button("OK") {
                saveError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var headerSection: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            Image(systemName: "sparkles")
                .font(.system(size: WelcomeConstants.iconSizeLarge))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.marketingPrimary, .marketingSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: UUID())
                .accessibilityHidden(true)

            Text("Welcome to Think", bundle: .module)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)

            Text(
                "Choose a language model to get started with your first chat",
                bundle: .module
            )
            .font(.title3)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: WelcomeConstants.maxTextWidth)
        }
        .padding(.top, WelcomeConstants.topPadding)
    }

    @ViewBuilder private var modelSelectionContent: some View {
        Group {
            if isLoadingRecommended {
                // Loading skeleton
                modelLoadingSkeleton
            } else if let error = recommendedError {
                // Error state
                WelcomeErrorView(
                    error: error,
                    loadAttempts: loadAttempts,
                    onRetry: loadRecommendedModels
                )
            } else if languageModels.isEmpty {
                // Empty state
                WelcomeEmptyStateView()
            } else {
                // Model selection
                modelSelectionSection
            }
        }
    }

    @ViewBuilder private var modelSelectionSection: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(
                            minimum: WelcomeConstants.gridMinWidth,
                            maximum: WelcomeConstants.gridMaxWidth
                        ))
                    ],
                    spacing: WelcomeConstants.spacingMedium
                ) {
                    ForEach(languageModels) { model in
                        ModelSelectionCard(
                            model: model,
                            isSelected: selectedModelId == model.id
                        ) {
                            selectedModelId = model.id
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: WelcomeConstants.maxScrollHeight)

            continueButton
        }
        .animation(.smooth(duration: WelcomeConstants.animationDuration), value: selectedModelId)
    }

    @ViewBuilder private var modelLoadingSkeleton: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(
                            minimum: WelcomeConstants.gridMinWidth,
                            maximum: WelcomeConstants.gridMaxWidth
                        ))
                    ],
                    spacing: WelcomeConstants.spacingMedium
                ) {
                    ForEach(0 ..< WelcomeConstants.skeletonCount, id: \.self) { _ in
                        WelcomeModelCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: WelcomeConstants.maxScrollHeight)
        }
    }

    @ViewBuilder private var continueButton: some View {
        Button {
            Task {
                await handleContinue()
            }
        } label: {
            Group {
                if isSavingModel {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(WelcomeConstants.progressViewScale)
                } else {
                    HStack {
                        Text("Continue", bundle: .module)
                            .fontWeight(.medium)

                        Image(systemName: "arrow.right")
                            .font(.footnote)
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: WelcomeConstants.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: WelcomeConstants.cornerRadiusSmall)
                    .fill(
                        selectedModelId != nil
                            ? Color.marketingPrimary
                            : Color.gray.opacity(WelcomeConstants.disabledButtonOpacity)
                    )
            )
        }
        .disabled(selectedModelId == nil || isSavingModel)
        .padding(.horizontal)
        .padding(.bottom, WelcomeConstants.bottomPadding)
    }

    // MARK: - Data Loading

    private func loadRecommendedModels() async {
        isLoadingRecommended = true
        recommendedError = nil
        loadAttempts += 1

        do {
            recommendedModels = try await viewModel.recommendedLanguageModels()
        } catch {
            recommendedError = error
        }

        isLoadingRecommended = false
    }

    // MARK: - Actions

    private func handleContinue() async {
        guard
            let modelId = selectedModelId,
            let discoveredModel = languageModels.first(where: { $0.id == modelId })
        else {
            return
        }

        await MainActor.run {
            isSavingModel = true
            saveError = nil
        }

        // Save the model to get its UUID
        if let savedModelId = await modelActions.save(discoveredModel) {
            // Start downloading the model immediately
            await modelActions.download(modelId: savedModelId)

            await MainActor.run {
                onModelSelected(savedModelId)
            }
        } else {
            // Model save failed
            await MainActor.run {
                saveError = NSError(
                    domain: "WelcomeView",
                    code: WelcomeConstants.errorCodeSaveFailed,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to save the selected model. Please try again."
                    ]
                )
                isSavingModel = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        WelcomeView { modelId in
            print("Selected model: \(modelId)")
        }
        .environment(\.discoveryCarousel, PreviewDiscoveryCarouselViewModel())
        .environment(\.modelActionsViewModel, PreviewModelActionsViewModel())
    }
#endif
