import Abstractions
import RemoteSession
import SwiftUI

internal struct WelcomeRemoteModelsModelsPanel: View {
    @Binding var selectedModel: RemoteModel?
    @Binding var searchText: String

    let isLoading: Bool
    let errorMessage: String?
    let models: [RemoteModel]
    let lastSuccessfulModels: [RemoteModel]

    let onRefresh: () -> Void

    internal var body: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            if let errorMessage {
                inlineErrorBanner(errorMessage)
            }

            searchField
            panelContent
        }
    }

    @ViewBuilder private var panelContent: some View {
        if isLoading, modelsToRender.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if modelsToRender.isEmpty {
            emptyState
        } else {
            modelsList
        }
    }

    private var emptyState: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            ContentUnavailableView(
                String(localized: "No Models Found", bundle: .module),
                systemImage: "sparkles",
                description: Text(
                    String(
                        localized: "Try a different provider or adjust your search.",
                        bundle: .module
                    )
                )
            )
            Button(action: onRefresh) {
                Text(String(localized: "Retry", bundle: .module))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var modelsList: some View {
        List {
            if !freeModels.isEmpty {
                sectionHeader("Free Models")
                modelRows(freeModels)
            }
            if !paidModels.isEmpty {
                sectionHeader("Paid Models")
                modelRows(paidModels)
            }
            if !otherModels.isEmpty {
                sectionHeader("Other Models")
                modelRows(otherModels)
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: WelcomeConstants.maxScrollHeight)
        .padding(.bottom, WelcomeRemoteModelsConstants.listBottomPadding)
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(spacing: WelcomeRemoteModelsConstants.bannerSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.paletteOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(WelcomeRemoteModelsConstants.descriptionLineLimit)
            Spacer(minLength: 0)
            Button(String(localized: "Retry", bundle: .module), action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding(WelcomeRemoteModelsConstants.bannerPadding)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.bannerCornerRadius))
        .overlay(errorBannerBorder)
    }

    private var errorBannerBorder: some View {
        RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.bannerCornerRadius)
            .stroke(
                Color.textSecondary.opacity(WelcomeRemoteModelsConstants.bannerStrokeOpacity),
                lineWidth: WelcomeRemoteModelsConstants.rowBorderWidth
            )
    }

    private var searchField: some View {
        HStack(spacing: WelcomeRemoteModelsConstants.searchFieldSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
                .accessibilityHidden(true)

            searchTextField

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityLabel(
                            Text(String(localized: "Clear search", bundle: .module))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, WelcomeRemoteModelsConstants.searchFieldPaddingH)
        .padding(.vertical, WelcomeRemoteModelsConstants.searchFieldPaddingV)
        .background(Color.backgroundSecondary)
        .clipShape(
            RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.searchFieldCornerRadius)
        )
        .overlay(searchFieldBorder)
    }

    @ViewBuilder private var searchTextField: some View {
        let field: TextField<Text> = TextField(
            String(localized: "Search models", bundle: .module),
            text: $searchText
        )

        #if os(iOS) || os(visionOS)
            field
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        #else
            field
        #endif
    }

    private var searchFieldBorder: some View {
        RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.searchFieldCornerRadius)
            .stroke(
                Color.textSecondary.opacity(WelcomeRemoteModelsConstants.searchFieldStrokeOpacity),
                lineWidth: WelcomeRemoteModelsConstants.rowBorderWidth
            )
    }

    private var modelsToRender: [RemoteModel] {
        let base: [RemoteModel] = models.isEmpty ? lastSuccessfulModels : models
        return filterModels(base)
    }

    private func filterModels(_ base: [RemoteModel]) -> [RemoteModel] {
        let languageOnly: [RemoteModel] = base.filter { model in
            switch model.type {
            case .language, .deepLanguage, .flexibleThinker:
                return true

            case .diffusion, .diffusionXL, .visualLanguage:
                return false
            }
        }

        guard !searchText.isEmpty else {
            return languageOnly
        }

        return languageOnly.filter { model in
            model.displayName.localizedCaseInsensitiveContains(searchText) ||
                model.modelId.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var freeModels: [RemoteModel] {
        modelsToRender.filter { $0.pricing == .free }
    }

    private var paidModels: [RemoteModel] {
        modelsToRender.filter { $0.pricing == .paid }
    }

    private var otherModels: [RemoteModel] {
        modelsToRender.filter { $0.pricing == .unknown }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .padding(.top, WelcomeRemoteModelsConstants.sectionHeaderTopPadding)
    }

    @ViewBuilder
    private func modelRows(_ models: [RemoteModel]) -> some View {
        ForEach(models) { model in
            WelcomeRemoteModelRow(
                model: model,
                isSelected: selectedModel?.id == model.id
            ) {
                selectedModel = model
            }
            .listRowSeparator(.hidden)
        }
    }
}
