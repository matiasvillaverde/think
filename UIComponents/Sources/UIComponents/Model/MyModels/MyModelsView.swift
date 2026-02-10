import Abstractions
import Database
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A view that displays the user's downloaded and downloading models
internal struct MyModelsView: View {
    // MARK: - Properties

    let chat: Chat
    @Binding var isDiscoveryPresented: Bool

    // MARK: - Initialization

    init(chat: Chat, isDiscoveryPresented: Binding<Bool>) {
        self.chat = chat
        _isDiscoveryPresented = isDiscoveryPresented
    }

    init(chat: Chat) {
        self.chat = chat
        _isDiscoveryPresented = .constant(false)
    }

    @Query private var models: [Model]

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @Environment(\.generator)
    private var generator: ViewModelGenerating

    @State private var showImportOptions: Bool = false
    @State private var showGGUFImporter: Bool = false
    @State private var showMLXImporter: Bool = false
    @State private var importErrorMessage: String?

    @State private var providerKeyStatus: [RemoteProviderType: Bool] = [:]
    @State private var remoteKeyEntryRequest: RemoteProviderType?

    #if os(macOS)
        @Environment(\.openWindow)
        private var openWindow: OpenWindowAction
        @Environment(\.dismiss)
        private var dismiss: DismissAction
    #endif

    // MARK: - Computed Properties

    private var downloadingModels: [Model] {
        models.filter { $0.locationKind != .remote && $0.state?.isDownloading == true }
    }

    private var downloadedModels: [Model] {
        models.filter { model in
            model.locationKind != .remote &&
                model.state?.isDownloaded == true &&
                model.state?.isDownloading != true
        }
    }

    private var remoteModels: [Model] {
        models.filter { $0.locationKind == .remote }
    }

    private var hasModels: Bool {
        !downloadingModels.isEmpty || !downloadedModels.isEmpty || !remoteModels.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if hasModels {
                    modelsContent
                } else {
                    emptyStateContent
                }
            }
        }
        .background(Color.backgroundPrimary)
        .background(
            RemoteAPIKeyCoordinator(
                providerKeyStatus: $providerKeyStatus,
                keyEntryRequest: $remoteKeyEntryRequest
            )
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImportOptions = true
                } label: {
                    Label {
                        Text("Add Local Model", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .confirmationDialog(
            Text("Add Local Model", bundle: .module),
            isPresented: $showImportOptions,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Import GGUF File", bundle: .module)) {
                showGGUFImporter = true
            }
            Button(String(localized: "Import MLX Folder", bundle: .module)) {
                showMLXImporter = true
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {
                showImportOptions = false
            }
        }
        .fileImporter(
            isPresented: $showGGUFImporter,
            allowedContentTypes: LocalImportKinds.ggufTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result, kind: .gguf)
        }
        .fileImporter(
            isPresented: $showMLXImporter,
            allowedContentTypes: LocalImportKinds.mlxTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result, kind: .mlx)
        }
        .alert(
            String(localized: "Import Error", bundle: .module),
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        importErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button(String(localized: "OK", bundle: .module)) {
                    importErrorMessage = nil
                }
            },
            message: {
                Text(importErrorMessage ?? "")
            }
        )
    }

    // MARK: - Private Views

    private var modelsContent: some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.large) {
                if !remoteModels.isEmpty {
                    remoteModelsSection
                }

                if !downloadingModels.isEmpty {
                    downloadingSection
                }

                if !downloadedModels.isEmpty {
                    downloadedSection
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
            .padding(.vertical, DesignConstants.Spacing.large)
        }
    }

    private var remoteModelsSection: some View {
        RemoteConfiguredModelsSection(
            models: remoteModels,
            chat: chat,
            providerKeyStatus: providerKeyStatus,
            onSelect: { model in
                Task {
                    await generator.modify(chatId: chat.id, modelId: model.id)
                }
            },
            onDelete: { model in
                Task {
                    await modelActions.delete(modelId: model.id)
                }
            },
            onAddKey: { provider in
                remoteKeyEntryRequest = provider
            }
        )
    }

    private var emptyStateContent: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            MyModelsEmptyState()
            Button {
                showImportOptions = true
            } label: {
                Label {
                    Text("Add Local Model", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.borderless)
            .padding(.bottom, DesignConstants.Spacing.large)
        }
    }

    private var downloadingSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityLabel(Text("Downloading", bundle: .module))

                Text("Downloading", bundle: .module)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DesignConstants.Spacing.small)

            ModelGroupView(
                models: downloadingModels,
                title: "",
                chat: chat
            )
        }
    }

    private var downloadedSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            downloadedHeader

            ModelGroupView(
                models: downloadedModels,
                title: "",
                chat: chat
            )
        }
    }

    private var downloadedHeader: some View {
        HStack {
            Text("My Models", bundle: .module)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Spacer()

            Text("\(downloadedModels.count)", bundle: .module)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignConstants.Spacing.small)
                .padding(.vertical, DesignConstants.Spacing.xSmall)
                .background(
                    Capsule()
                        .fill(Color.backgroundSecondary)
                )

            Spacer()

            Button {
                showImportOptions = true
            } label: {
                Label {
                    Text("Add Local Model", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle")
                        .accessibilityHidden(true)
                }
                    .labelStyle(.iconOnly)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignConstants.Spacing.small)
    }

    func setImportErrorMessage(_ message: String?) {
        importErrorMessage = message
    }

    func addLocalModelEntry(_ importModel: LocalModelImport) async -> UUID? {
        await modelActions.addLocalModel(importModel)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var isDiscoveryPresented: Bool = false
    MyModelsView(chat: .preview, isDiscoveryPresented: $isDiscoveryPresented)
}
#endif
