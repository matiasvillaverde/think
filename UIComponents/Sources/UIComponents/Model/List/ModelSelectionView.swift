import Abstractions
import Database
import SwiftData
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

// **MARK: - Main View**

/// Model list
internal struct ModelSelectionView: View {
    @Bindable private var chat: Chat

    @Query private var allModels: [Model]

    // Add a state property to track the current filter mode
    @State private var filterMode: FilterMode = .recommended

    init(chat: Chat) {
        self.chat = chat
        let availableMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        _allModels = Query(
            filter: #Predicate<Model> { model in
                model.ramNeeded < availableMemory
            },
            animation: .easeInOut
        )
    }

    // **MARK: - Constants**

    enum Constants {
        static let downloadingModels: String = "downloadingModelsSection"
    }

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            ModelListContainerView(
                filterMode: $filterMode,
                chat: chat,
                selectedModels: selectedInChatModels,
                downloadedModels: downloadedModels,
                downloadingModels: downloadingModels,
                notDownloadedModels: notDownloadedModels
            )
            .background(Color.backgroundPrimary)
            .opacity(DesignConstants.Opacity.backgroundBlur)
        }
        #if canImport(UIKit)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    // Get the device's available RAM
    private var deviceRam: UInt64 {
        // In a real app, you'd use a system API to get this
        // For now, let's get the physical memory in MB
        ProcessInfo.processInfo.physicalMemory
    }

    // Get recommended models that fit device RAM requirements (best of each primary type)
    private var recommendedModels: [Model] {
        // Assuming we're looking for image, language, and deep language models
        let modelTypes: [SendableModel.ModelType] = [
            .diffusion, // For generating images
            .diffusionXL,
            .language, // For generating text/visual
            .flexibleThinker,
            .visualLanguage,
            .deepLanguage // For deep thinking
        ]

        var recommendedList: [Model] = []

        // For each target type, find the model with the highest RAM that still fits device RAM
        for modelType in modelTypes {
            let modelsOfType: [Model] = allModels
                .filter { (model: Model) in
                    model.type == modelType && model.ramNeeded <= deviceRam
                }
                .sorted { (first: Model, second: Model) in
                    first.ramNeeded > second.ramNeeded
                }

            if let bestModelOfType = modelsOfType.first {
                recommendedList.append(bestModelOfType)
            }
        }

        return recommendedList
    }

    // These are the 2 selected models from the Chat
    private var selectedModelsInChat: [Model] {
        [chat.languageModel, chat.imageModel]
            .sorted { (first: Model, second: Model) in
                first.ramNeeded < second.ramNeeded
            }
    }

    // Filter models based on the selected filter mode
    private var filteredAllModels: [Model] {
        // Always exclude selected models from Chat for ALL and RECOMMENDED views
        let excludedNames: Set<String> = Set(selectedModelsInChat.map(\.name))

        switch filterMode {
        case .all:
            return allModels.filter { !excludedNames.contains($0.name) }

        case .selected:
            return [] // Empty because we handle selected models separately

        case .recommended:
            return recommendedModels.filter { !excludedNames.contains($0.name) }
        }
    }

    // Filter selected models based on current filter mode
    private var selectedInChatModels: [Model] {
        switch filterMode {
        case .all, .recommended:
            []

        case .selected:
            selectedModelsInChat
        }
    }

    private func filterModels(
        by stateFilter: (Model.State) -> Bool,
        excluding excludedModels: [Model]
    ) -> [Model] {
        let excludedNames: Set<String> = Set(excludedModels.map(\.name))
        return filteredAllModels.filter { (model: Model) in
            stateFilter(model.state ?? .notDownloaded) && !excludedNames.contains(model.name)
        }
    }

    private var downloadedModels: [Model] {
        filterModels(by: { $0.isDownloaded }, excluding: selectedInChatModels)
    }

    private var downloadingModels: [Model] {
        filterModels(by: { $0.isDownloading }, excluding: selectedInChatModels + downloadedModels)
    }

    private var notDownloadedModels: [Model] {
        let excluded: [Model] = selectedInChatModels + downloadedModels + downloadingModels
        return filterModels(by: { $0.isNotDownloaded }, excluding: excluded)
    }
}

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var chat: Chat = .preview
        ModelSelectionView(chat: chat)
    }
#endif
