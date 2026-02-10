import Abstractions
import Database
import SwiftUI

internal struct PersonalityModelSelectionSection: View {
    let allModels: [Model]

    @Binding var selectedSource: PersonalityModelSource
    @Binding var selectedModelId: UUID?
    @Binding var providerKeyStatus: [RemoteProviderType: Bool]
    @Binding var remoteKeyEntryRequest: RemoteProviderType?
    @Binding var modelErrorMessage: String?

    internal var body: some View {
        Section {
            Picker(
                String(localized: "Model Source", bundle: .module),
                selection: $selectedSource
            ) {
                ForEach(PersonalityModelSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedSource) { _, _ in
                selectedModelId = nil
                modelErrorMessage = nil
            }

            if let modelErrorMessage {
                Text(modelErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.paletteOrange)
            }

            modelPicker
        } header: {
            Text("Model", bundle: .module)
        } footer: {
            Text(
                String(
                    localized: """
                    Pick a model to power this personality. Remote models require an API key.
                    """,
                    bundle: .module
                )
            )
        }
    }

    @ViewBuilder private var modelPicker: some View {
        switch selectedSource {
        case .local:
            localModelsPicker

        case .remote:
            remoteModelsPicker
        }
    }

    @ViewBuilder private var localModelsPicker: some View {
        if localLanguageModelsDownloaded.isEmpty {
            ContentUnavailableView(
                String(localized: "No Local Models", bundle: .module),
                systemImage: "cpu",
                description: Text(
                    String(
                        localized: "Download a local model first, or pick a remote model.",
                        bundle: .module
                    )
                )
            )
        } else {
            ForEach(localLanguageModelsDownloaded, id: \.id) { model in
                ModelChoiceRow(
                    title: model.displayName,
                    subtitle: model.displayDescription,
                    icon: iconView(systemName: "cpu"),
                    isSelected: selectedModelId == model.id,
                    statusPill: nil
                ) {
                    selectedModelId = model.id
                    modelErrorMessage = nil
                }
            }
        }
    }

    @ViewBuilder private var remoteModelsPicker: some View {
        if remoteLanguageModels.isEmpty {
            ContentUnavailableView(
                String(localized: "No Remote Models Added", bundle: .module),
                systemImage: "globe",
                description: Text(
                    String(
                        localized: "Add a remote model in Remote Models, then come back here.",
                        bundle: .module
                    )
                )
            )
        } else {
            ForEach(remoteLanguageModels, id: \.id) { model in
                remoteModelRow(model)
            }
        }
    }

    private func remoteModelRow(_ model: Model) -> some View {
        let provider: RemoteProviderType? = RemoteProviderType.fromRemoteLocation(
            model.locationHuggingface ?? ""
        )
        let isKeyConfigured: Bool = provider.map { providerKeyStatus[$0] ?? false } ?? true
        let statusPill: String? =
            isKeyConfigured ? nil : String(localized: "Key required", bundle: .module)
        let icon: AnyView = provider.map { iconView(assetName: $0.assetName) }
            ?? iconView(systemName: "globe")

        return ModelChoiceRow(
            title: model.displayName,
            subtitle: provider?.displayName ?? String(localized: "Remote", bundle: .module),
            icon: icon,
            isSelected: selectedModelId == model.id,
            statusPill: statusPill
        ) {
            if isKeyConfigured {
                selectedModelId = model.id
                modelErrorMessage = nil
            } else if let provider {
                remoteKeyEntryRequest = provider
            }
        }
    }

    private func iconView(systemName: String) -> AnyView {
        AnyView(
            Image(systemName: systemName)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        )
    }

    private func iconView(assetName: String) -> AnyView {
        AnyView(
            Image(ImageResource(name: assetName, bundle: .module))
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        )
    }

    private var localLanguageModelsDownloaded: [Model] {
        allModels
            .filter { $0.locationKind != .remote }
            .filter { $0.state?.isDownloaded == true }
            .filter { model in
                switch model.type {
                case .language, .deepLanguage, .flexibleThinker, .visualLanguage:
                    return true

                case .diffusion, .diffusionXL:
                    return false
                }
            }
            .sorted { $0.displayName < $1.displayName }
    }

    private var remoteLanguageModels: [Model] {
        allModels
            .filter { $0.locationKind == .remote }
            .filter { model in
                switch model.type {
                case .language, .deepLanguage, .flexibleThinker, .visualLanguage:
                    return true

                case .diffusion, .diffusionXL:
                    return false
                }
            }
            .sorted { $0.displayName < $1.displayName }
    }
}
