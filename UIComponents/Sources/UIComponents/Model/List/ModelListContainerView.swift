import Database
import SwiftUI

// **MARK: - Model List Container View**

internal struct ModelListContainerView: View {
    @Binding private var filterMode: FilterMode
    private let chat: Chat
    private let selectedModels: [Model]
    private let downloadedModels: [Model]
    private let downloadingModels: [Model]
    private let notDownloadedModels: [Model]

    init(
        filterMode: Binding<FilterMode>,
        chat: Chat,
        selectedModels: [Model],
        downloadedModels: [Model],
        downloadingModels: [Model],
        notDownloadedModels: [Model]
    ) {
        _filterMode = filterMode
        self.chat = chat
        self.selectedModels = selectedModels
        self.downloadedModels = downloadedModels
        self.downloadingModels = downloadingModels
        self.notDownloadedModels = notDownloadedModels
    }

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.standard) {
            FilterControlView(filterMode: $filterMode)

            ScrollView {
                ScrollViewReader { proxy in
                    ModelListContentView(
                        chat: chat,
                        selectedModels: selectedModels,
                        downloadedModels: downloadedModels,
                        downloadingModels: downloadingModels,
                        notDownloadedModels: notDownloadedModels,
                        proxy: proxy
                    )
                }
            }
        }
    }

    // MARK: - Private View Components

    private struct ModelListContentView: View {
        let chat: Chat
        let selectedModels: [Model]
        let downloadedModels: [Model]
        let downloadingModels: [Model]
        let notDownloadedModels: [Model]
        let proxy: ScrollViewProxy

        var body: some View {
            LazyVStack(spacing: DesignConstants.Spacing.large) {
                ModelGroupView(
                    models: downloadingModels,
                    title: String(localized: "Downloading", bundle: .module),
                    chat: chat
                )
                .id("downloadingModels")

                if selectedModels.isEmpty,
                    downloadedModels.isEmpty,
                    notDownloadedModels.isEmpty,
                    downloadingModels.isEmpty {
                    usingRecommendedModels
                } else {
                    ModelGroupView(
                        models: selectedModels,
                        title: String(localized: "Active Models in Current Chat", bundle: .module),
                        chat: chat
                    )

                    ModelGroupView(
                        models: downloadedModels,
                        title: String(localized: "Downloaded Models", bundle: .module),
                        chat: chat
                    )

                    ModelGroupView(
                        models: notDownloadedModels,
                        title: String(localized: "Available to Download", bundle: .module),
                        chat: chat
                    )

                    DisclaimerView()
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
            .padding(.top, DesignConstants.Spacing.large)
            .onChange(of: downloadingModels) { _, newValue in
                if !newValue.isEmpty {
                    withAnimation {
                        proxy.scrollTo("downloadingModels", anchor: .top)
                    }
                }
            }
        }

        private var usingRecommendedModels: some View {
            Text("🎉 Great, you are using the best models available! 🎉", bundle: .module)
                .font(.title)
                .bold()
                .foregroundColor(Color.textPrimary)
                .padding(.top)
        }
    }

    private struct SelectedModelsView: View {
        let models: [Model]
        let chat: Chat

        var body: some View {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.standard) {
                SectionHeaderView(
                    title: String(
                        localized: "Currently Selected",
                        bundle: .module
                    )
                )
                ModelSectionView(models: models, chat: chat)
            }
        }
    }
}
