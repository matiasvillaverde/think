import Abstractions
import Database
import RemoteSession
import SwiftData
import SwiftUI
import ViewModels

private enum PersonalityEditLayout {
    static let overlayOpacity: Double = 0.3
    static let progressViewScale: CGFloat = 1.5
    static let soulEditorMinHeight: CGFloat = 120
    static let openClawIconSize: CGFloat = 24
}

/// View for editing an existing personality.
internal struct PersonalityEditView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: ViewModels.PersonalityEditViewModel

    private let personalityId: UUID
    private let database: DatabaseProtocol

    @Environment(\.apiKeyManager)
    private var apiKeyManager: APIKeyManaging

    @Query private var allModels: [Model]

    @State private var selectedModelId: UUID?
    @State private var selectedModelSource: PersonalityModelSource = .local
    @State private var providerKeyStatus: [RemoteProviderType: Bool] = [:]
    @State private var remoteKeyEntryRequest: RemoteProviderType?
    @State private var modelErrorMessage: String?

    internal init(
        isPresented: Binding<Bool>,
        personality: Personality,
        database: DatabaseProtocol
    ) {
        _isPresented = isPresented
        self.personalityId = personality.id
        self.database = database
        _viewModel = StateObject(
            wrappedValue: ViewModels.PersonalityEditViewModel(
                database: database,
                personalityId: personality.id
            )
        )
    }

    internal var body: some View {
        rootView
    }

    private var rootView: some View {
        NavigationStack { navigationContent }
            .task {
                await viewModel.loadPersonality()
                await refreshProviderKeyStatus()
                await loadCurrentChatModel()
            }
    }

    private var navigationContent: some View {
        formContent
            .navigationTitle(String(localized: "Edit Personality", bundle: .module))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .disabled(viewModel.isUpdating || viewModel.isLoading)
            .overlay { if viewModel.isUpdating || viewModel.isLoading { loadingOverlay } }
            .alert(
                String(localized: "Error", bundle: .module),
                isPresented: .constant(viewModel.validationError != nil)
            ) {
                Button(String(localized: "OK", bundle: .module)) {
                    viewModel.validationError = nil
                }
            } message: {
                Text(viewModel.validationError ?? "")
            }
            .background(
                RemoteAPIKeyCoordinator(
                    providerKeyStatus: $providerKeyStatus,
                    keyEntryRequest: $remoteKeyEntryRequest
                )
            )
    }

    private var formContent: some View {
        Form {
            basicsSection
            soulSection
            modelSection
            openClawSection
            deleteSection
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Cancel", bundle: .module)) {
                isPresented = false
            }
        }
        ToolbarItem(placement: .confirmationAction) { saveButton }
    }

    private var basicsSection: some View {
        Section {
            TextField(String(localized: "Name", bundle: .module), text: $viewModel.name)
            TextField(
                String(localized: "Description", bundle: .module),
                text: $viewModel.description
            )

            Picker(
                String(localized: "Category", bundle: .module),
                selection: $viewModel.selectedCategory
            ) {
                ForEach(PersonalityCategory.sortedCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
        } header: {
            Text("Details", bundle: .module)
        }
    }

    private var soulSection: some View {
        Section {
            TextEditor(text: $viewModel.soul)
                .frame(minHeight: PersonalityEditLayout.soulEditorMinHeight)
        } header: {
            Text("Soul (Identity)", bundle: .module)
        }
    }

    private var modelSection: some View {
        PersonalityModelSelectionSection(
            allModels: allModels,
            selectedSource: $selectedModelSource,
            selectedModelId: $selectedModelId,
            providerKeyStatus: $providerKeyStatus,
            remoteKeyEntryRequest: $remoteKeyEntryRequest,
            modelErrorMessage: $modelErrorMessage
        )
    }

    private var openClawSection: some View {
        Section {
            NavigationLink {
                OpenClawSetupView()
            } label: {
                Label {
                    Text("Connect OpenClaw Gateway", bundle: .module)
                } icon: {
                    Image(ImageResource(name: "openclaw-claw", bundle: .module))
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: PersonalityEditLayout.openClawIconSize,
                            height: PersonalityEditLayout.openClawIconSize
                        )
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var deleteSection: some View {
        Group {
            if viewModel.isDeletable {
                Section {
                    Button(role: .destructive) {
                        Task { await delete() }
                    } label: {
                        Text("Delete Personality", bundle: .module)
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button(String(localized: "Save", bundle: .module)) {
            Task { await save() }
        }
        .disabled(viewModel.isUpdating || viewModel.isLoading)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.paletteBlack.opacity(PersonalityEditLayout.overlayOpacity)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(PersonalityEditLayout.progressViewScale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Saving personality", bundle: .module)))
    }

    @MainActor
    private func save() async {
        let isSuccessful: Bool = await viewModel.updatePersonality()
        guard isSuccessful else {
            return
        }
        await applyModelSelectionIfNeeded()
        isPresented = false
    }

    @MainActor
    private func delete() async {
        let isSuccessful: Bool = await viewModel.deletePersonality()
        guard isSuccessful else {
            return
        }
        isPresented = false
    }

    @MainActor
    private func applyModelSelectionIfNeeded() async {
        guard let selectedModelId else {
            return
        }

        do {
            let chatId: UUID = try await database.write(
                PersonalityCommands.GetChat(personalityId: personalityId)
            )
            try await database.write(
                ChatCommands.UpdateChatModel(chatId: chatId, modelId: selectedModelId)
            )
        } catch {
            modelErrorMessage = error.localizedDescription
        }
    }

    private func refreshProviderKeyStatus() async {
        var status: [RemoteProviderType: Bool] = [:]
        for provider in RemoteProviderType.allCases {
            status[provider] = await apiKeyManager.hasKey(for: provider)
        }
        providerKeyStatus = status
    }

    private func loadCurrentChatModel() async {
        do {
            let personality: Personality = try await database.read(
                PersonalityCommands.Read(personalityId: personalityId)
            )
            if let current = personality.chat?.languageModel {
                selectedModelId = current.id
                selectedModelSource = current.locationKind == .remote ? .remote : .local
            }
        } catch {
            // Ignore; user can still edit other fields.
        }
    }
}

#if DEBUG
#Preview {
    PreviewPersonalityEditView()
        .withDatabase()
}

private struct PreviewPersonalityEditView: View {
    @Environment(\.database)
    private var database: DatabaseProtocol

    @State private var isPresented: Bool = true

    var body: some View {
        PersonalityEditView(
            isPresented: $isPresented,
            personality: .preview,
            database: database
        )
    }
}
#endif
