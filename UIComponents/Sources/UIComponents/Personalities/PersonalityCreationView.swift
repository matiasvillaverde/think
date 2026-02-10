import Abstractions
import Database
import PhotosUI
import RemoteSession
import SwiftData
import SwiftUI
import ViewModels

private enum PersonalityCreationLayout {
    static let overlayOpacity: Double = 0.3
    static let progressViewScale: CGFloat = 1.5
    static let soulEditorMinHeight: CGFloat = 120
    static let openClawIconSize: CGFloat = 24
}

/// View for creating custom personalities.
internal struct PersonalityCreationView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: ViewModels.PersonalityCreationViewModel

    @Environment(\.database)
    private var database: DatabaseProtocol

    @Environment(\.apiKeyManager)
    private var apiKeyManager: APIKeyManaging

    @Query private var allModels: [Model]

    @State private var selectedModelId: UUID?
    @State private var selectedModelSource: PersonalityModelSource = .local
    @State private var providerKeyStatus: [RemoteProviderType: Bool] = [:]
    @State private var remoteKeyEntryRequest: RemoteProviderType?
    @State private var soul: String = ""
    @State private var modelErrorMessage: String?

    internal init(
        isPresented: Binding<Bool>,
        chatViewModel: ChatViewModeling
    ) {
        _isPresented = isPresented
        _viewModel = StateObject(
            wrappedValue: ViewModels.PersonalityCreationViewModel(chatViewModel: chatViewModel)
        )
    }

    internal var body: some View {
        rootView
    }

    private var rootView: some View {
        NavigationStack { navigationContent }
            .task {
                await refreshProviderKeyStatus()
            }
    }

    private var navigationContent: some View {
        formContent
            .navigationTitle(String(localized: "Create Personality", bundle: .module))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .disabled(viewModel.isCreating)
            .overlay { if viewModel.isCreating { loadingOverlay } }
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
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Cancel", bundle: .module)) {
                isPresented = false
            }
        }
        ToolbarItem(placement: .confirmationAction) { createButton }
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

            PhotosPicker(
                selection: $viewModel.selectedImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label {
                    Text("Choose Image", bundle: .module)
                } icon: {
                    Image(systemName: "photo")
                        .accessibilityHidden(true)
                }
            }
        } header: {
            Text("Details", bundle: .module)
        } footer: {
            Text(
                String(
                    localized: "Your personality image appears in the sidebar and chat.",
                    bundle: .module
                )
            )
        }
    }

    private var soulSection: some View {
        Section {
            TextEditor(text: $soul)
                .frame(minHeight: PersonalityCreationLayout.soulEditorMinHeight)
        } header: {
            Text("Soul (Identity)", bundle: .module)
        } footer: {
            Text(
                String(
                    localized: """
                    A short identity note. It is stored locally and used as long‑term context
                    for this personality.
                    """,
                    bundle: .module
                )
            )
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
                            width: PersonalityCreationLayout.openClawIconSize,
                            height: PersonalityCreationLayout.openClawIconSize
                        )
                        .accessibilityHidden(true)
                }
            }
        } footer: {
            Text(
                String(
                    localized: """
                    Use an OpenClaw instance to route requests through your own gateway.
                    """,
                    bundle: .module
                )
            )
        }
    }

    private var createButton: some View {
        Button(String(localized: "Create", bundle: .module)) {
            Task {
                await create()
            }
        }
        .disabled(viewModel.isCreating)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.paletteBlack.opacity(PersonalityCreationLayout.overlayOpacity)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(PersonalityCreationLayout.progressViewScale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Creating personality", bundle: .module)))
    }

    @MainActor
    private func create() async {
        let created: Bool = await viewModel.createPersonality()
        guard created, let personalityId = viewModel.createdPersonalityId else {
            return
        }

        await postCreate(personalityId: personalityId)
        isPresented = false
    }

    @MainActor
    private func postCreate(personalityId: UUID) async {
        do {
            if let selectedModelId {
                let chatId: UUID = try await database.write(
                    PersonalityCommands.GetChat(personalityId: personalityId)
                )
                try await database.write(
                    ChatCommands.UpdateChatModel(chatId: chatId, modelId: selectedModelId)
                )
            }

            let trimmedSoul: String = soul.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSoul.isEmpty {
                try await database.write(
                    MemoryCommands.UpsertPersonalitySoul(
                        personalityId: personalityId,
                        content: trimmedSoul
                    )
                )
            }
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
}

#if DEBUG
#Preview {
    PersonalityCreationView(
        isPresented: .constant(true),
        chatViewModel: PreviewChatViewModel()
    )
    .withDatabase()
}
#endif
