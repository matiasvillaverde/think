import Abstractions
import SwiftUI

internal struct WelcomeSelectionContent: View {
    let selectedSource: WelcomeView.ModelSource
    let languageModels: [DiscoveredModel]
    let isLoadingRecommended: Bool
    let recommendedError: Error?
    let loadAttempts: Int
    @Binding var selectedModelId: String?
    @Binding var selectedRemoteModel: RemoteModel?
    let isSavingModel: Bool
    let canContinue: Bool
    let onRetry: () async -> Void
    let onContinue: () async -> Void

    var body: some View {
        switch selectedSource {
        case .local:
            localSelectionContent

        case .remote:
            remoteSelectionContent
        }
    }

    private var localSelectionContent: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            WelcomeLocalModelsSection(
                languageModels: languageModels,
                isLoadingRecommended: isLoadingRecommended,
                recommendedError: recommendedError,
                loadAttempts: loadAttempts,
                onRetry: onRetry,
                selectedModelId: $selectedModelId
            )
            WelcomeContinueButton(
                isSaving: isSavingModel,
                isEnabled: canContinue,
                onContinue: onContinue
            )
        }
        .animation(.smooth(duration: WelcomeConstants.animationDuration), value: selectedModelId)
    }

    private var remoteSelectionContent: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            WelcomeRemoteModelsSection(selectedModel: $selectedRemoteModel)
            WelcomeContinueButton(
                isSaving: isSavingModel,
                isEnabled: canContinue,
                onContinue: onContinue
            )
        }
        .animation(
            .smooth(duration: WelcomeConstants.animationDuration),
            value: selectedRemoteModel
        )
    }
}

#if DEBUG
#Preview {
    WelcomeSelectionContent(
        selectedSource: .local,
        languageModels: [],
        isLoadingRecommended: true,
        recommendedError: nil,
        loadAttempts: 0,
        selectedModelId: .constant(nil),
        selectedRemoteModel: .constant(nil),
        isSavingModel: false,
        canContinue: false,
        onRetry: { _ = () },
        onContinue: { _ = () }
    )
    .padding()
}
#endif
