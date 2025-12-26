import Abstractions
import SwiftUI

internal struct WelcomeLocalModelsSection: View {
    let languageModels: [DiscoveredModel]
    let isLoadingRecommended: Bool
    let recommendedError: Error?
    let loadAttempts: Int
    let onRetry: () async -> Void
    @Binding var selectedModelId: String?

    var body: some View {
        Group {
            if isLoadingRecommended {
                modelLoadingSkeleton
            } else if let error = recommendedError {
                WelcomeErrorView(
                    error: error,
                    loadAttempts: loadAttempts,
                    onRetry: onRetry
                )
            } else if languageModels.isEmpty {
                WelcomeEmptyStateView()
            } else {
                modelSelectionSection
            }
        }
    }

    private var modelSelectionSection: some View {
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
    }

    private var modelLoadingSkeleton: some View {
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

#if DEBUG
#Preview {
    WelcomeLocalModelsSection(
        languageModels: [],
        isLoadingRecommended: true,
        recommendedError: nil,
        loadAttempts: 0,
        onRetry: { _ = () },
        selectedModelId: .constant(nil)
    )
}
#endif
