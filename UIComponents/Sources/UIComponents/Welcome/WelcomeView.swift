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
    @State private var selectedRemoteModel: RemoteModel?
    @State private var isSavingModel: Bool = false
    @State private var saveError: Error?
    @State private var loadAttempts: Int = 0
    @State private var selectedSource: ModelSource = .local

    // MARK: - Properties

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @Environment(\.remoteModelsViewModel)
    private var remoteModelsViewModel: RemoteModelsViewModeling

    private let onModelSelected: (UUID) -> Void

    // MARK: - Initialization

    public init(onModelSelected: @escaping (UUID) -> Void) {
        self.onModelSelected = onModelSelected
    }

    enum ModelSource: String, CaseIterable, Identifiable {
        case local = "localModels"
        case remote = "remoteModels"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local:
                return String(localized: "Local Models", bundle: .module)

            case .remote:
                return String(localized: "Remote Models", bundle: .module)
            }
        }
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

    private var canContinue: Bool {
        switch selectedSource {
        case .local:
            return selectedModelId != nil

        case .remote:
            return selectedRemoteModel != nil
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            WelcomeHeaderSection()

            WelcomeModelSourcePicker(selectedSource: $selectedSource)

            WelcomeSelectionContent(
                selectedSource: selectedSource,
                languageModels: languageModels,
                isLoadingRecommended: isLoadingRecommended,
                recommendedError: recommendedError,
                loadAttempts: loadAttempts,
                selectedModelId: $selectedModelId,
                selectedRemoteModel: $selectedRemoteModel,
                isSavingModel: isSavingModel,
                canContinue: canContinue,
                onRetry: loadRecommendedModels,
                onContinue: handleContinue
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .task {
            await loadRecommendedModels()
        }
        .onChange(of: selectedSource) { _, newValue in
            switch newValue {
            case .local:
                selectedRemoteModel = nil

            case .remote:
                selectedModelId = nil
            }
        }
        .alert(
            String(localized: "Error", bundle: .module),
            isPresented: .constant(saveError != nil),
            presenting: saveError
        ) { _ in
            Button(String(localized: "OK", bundle: .module)) {
                saveError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Subviews

    // MARK: - Data Loading

    private func loadRecommendedModels() async {
        isLoadingRecommended = true
        recommendedError = nil
        loadAttempts += 1
        recommendedModels = await viewModel.recommendedLanguageModels()

        isLoadingRecommended = false
    }

    // MARK: - Actions

    private func handleContinue() async {
        switch selectedSource {
        case .local:
            await handleLocalContinue()

        case .remote:
            await handleRemoteContinue()
        }
    }

    private func handleLocalContinue() async {
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

        if let savedModelId = await modelActions.save(discoveredModel) {
            await modelActions.download(modelId: savedModelId)

            await MainActor.run {
                onModelSelected(savedModelId)
            }
        } else {
            await MainActor.run {
                saveError = NSError(
                    domain: "WelcomeView",
                    code: WelcomeConstants.errorCodeSaveFailed,
                    userInfo: [
                        NSLocalizedDescriptionKey: String(
                            localized: "Failed to save the selected model. Please try again.",
                            bundle: .module
                        )
                    ]
                )
                isSavingModel = false
            }
        }
    }

    private func handleRemoteContinue() async {
        guard let selectedRemoteModel else {
            return
        }

        await MainActor.run {
            isSavingModel = true
            saveError = nil
        }

        do {
            let modelId: UUID = try await remoteModelsViewModel.selectModel(
                selectedRemoteModel,
                chatId: UUID()
            )
            await MainActor.run {
                onModelSelected(modelId)
            }
        } catch {
            await MainActor.run {
                saveError = error
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
        .environment(\.remoteModelsViewModel, PreviewRemoteModelsViewModel())
    }
#endif
