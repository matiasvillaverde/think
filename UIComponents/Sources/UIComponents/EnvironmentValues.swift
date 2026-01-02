import Abstractions
import SwiftUI

// MARK: - ViewModels Integration

extension EnvironmentValues {
    /// Access to the attachment handler view model
    ///
    /// This environment value provides access to the `ViewModelAttaching` protocol implementation,
    /// which handles file operations such as processing and deleting attachments.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct MyView: View {
    ///     @Environment(\.attacher) private var attacher
    ///
    ///     var body: some View {
    ///         Button("Process File") {
    ///             let fileURL = URL(fileURLWithPath: "/path/to/file")
    ///             Task {
    ///                 await attacher.process(file: fileURL)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var attacher: ViewModelAttaching = PreviewViewModelAttacher()

    /// Access to the generator view model
    ///
    /// This environment value provides access to the `ViewModelGenerating` protocol implementation,
    /// which handles AI content generation operations including loading models,
    /// generating responses, and managing the generation lifecycle.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct ChatView: View {
    ///     @Environment(\.generator) private var generator
    ///     @State private var prompt: String = ""
    ///
    ///     var body: some View {
    ///         VStack {
    ///             TextField("Enter prompt", text: $prompt)
    ///             Button("Generate") {
    ///                 Task {
    ///                     await generator.generate(prompt: prompt)
    ///                 }
    ///             }
    ///         }
    ///         .task {
    ///             // Load the model for a specific chat
    ///             await generator.load(chatId: selectedChatId)
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var generator: ViewModelGenerating = PreviewGenerator()

    /// Access to the image handler view model
    ///
    /// This environment value provides access to the `ViewModelImaging` protocol implementation,
    /// which handles image operations such as saving, sharing, and copying images.
    @Entry public var imageHandler: ViewModelImaging = PreviewImageHandler()

    /// Access to the view interaction controller
    ///
    /// This environment value provides access to the `ViewInteractionController` which manages
    /// UI-specific interactions such as focus management and scroll positioning.
    /// Note that this controller must be accessed on the main actor.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct ChatInputView: View {
    ///     @Environment(\.interactionController) private var interactionController
    ///     @FocusState private var isFocused: Bool
    ///
    ///     var body: some View {
    ///         TextField("Type a message", text: $text)
    ///             .focused($isFocused)
    ///             .onAppear {
    ///                 interactionController.removeFocus = { isFocused = false }
    ///                 interactionController.focus = { isFocused = true }
    ///             }
    ///     }
    /// }
    /// ```
    var controller: ViewInteractionController {
        get { self[ViewInteractionControllerKey.self] }
        set { self[ViewInteractionControllerKey.self] = newValue }
    }

    /// Access to the chat view model
    ///
    /// This environment value provides access to the `ChatViewModeling` protocol implementation,
    /// which handles chat operations such as creating, deleting, and renaming chats.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct ChatListView: View {
    ///     @Environment(\.chatViewModel) private var chatViewModel
    ///     @State private var chats: [Chat] = []
    ///     @State private var newChatName: String = ""
    ///
    ///     var body: some View {
    ///         VStack {
    ///             List(chats) { chat in
    ///                 Text(chat.name)
    ///                     .swipeActions {
    ///                         Button("Delete") {
    ///                             Task {
    ///                                 await chatViewModel.delete(chatId: chat.id)
    ///                             }
    ///                         }
    ///                         .tint(.red)
    ///                     }
    ///             }
    ///
    ///             Button("New Chat") {
    ///                 Task {
    ///                     await chatViewModel.addChat()
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var chatViewModel: ChatViewModeling = PreviewChatViewModel()

    /// ViewModel to mark a notification as viewed
    @Entry public var notificationViewModel: ViewModelNotifying = PreviewNotifier()

    /// ViewModel to initialize the database
    @Entry public var appViewModel: AppViewModeling = PreviewAppViewModel()

    /// ViewModel to ask for reviews
    @Entry public var reviewPromptViewModel: ReviewPromptManaging = PreviewReviewViewModel()

    /// ViewModel for plugin approval management
    @Entry public var pluginApprovalViewModel: PluginApprovalViewModeling =
        PreviewPluginApprovalViewModel()

    /// ViewModel for generating audio
    @Entry public var audioViewModel: AudioViewModeling = PreviewAudioGenerator()

    /// ViewModel for node mode controls
    @Entry public var nodeModeViewModel: NodeModeViewModeling = PreviewNodeModeViewModel()

    /// Tool validator for checking tool requirements
    @Entry public var toolValidator: ToolValidating?

    /// Access to the image generator for Core ML image generation
    ///
    /// This environment value provides access to the `ImageGenerating` protocol implementation,
    /// which handles Core ML-based image generation using Stable Diffusion models.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct ImageGeneratorView: View {
    ///     @Environment(\.imageGenerator) private var imageGenerator
    ///     @State private var prompt: String = ""
    ///
    ///     var body: some View {
    ///         VStack {
    ///             TextField("Enter prompt", text: $prompt)
    ///             Button("Generate Image") {
    ///                 Task {
    ///                     let config = ImageConfiguration(prompt: prompt)
    ///                     for try await (image, stats) in imageGenerator.generate(
    ///                         model: selectedModel,
    ///                         config: config
    ///                     ) {
    ///                         // Display generated image
    ///                     }
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var imageGenerator: ImageGenerating?

    /// Access to the image generation view model
    ///
    /// This environment value provides access to the `ViewModelImageGenerating` protocol
    /// implementation,
    /// which handles visual content generation at the view model layer, managing the complete
    /// lifecycle of image generation including model loading, generation, database persistence,
    /// and UI feedback.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct ImageGenerationView: View {
    ///     @Environment(\.imageGeneratorViewModel) private var imageGeneratorViewModel
    ///     @State private var prompt: String = ""
    ///
    ///     var body: some View {
    ///         VStack {
    ///             TextField("Enter prompt", text: $prompt)
    ///             Button("Generate Image") {
    ///                 Task {
    ///                     try await imageGeneratorViewModel.generateImage(
    ///                         prompt: prompt,
    ///                         model: selectedModel,
    ///                         chatId: currentChatId,
    ///                         messageId: messageId,
    ///                         contextPrompt: enhancedPrompt
    ///                     )
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var imageGeneratorViewModel: ViewModelImageGenerating?

    /// Access to the discovery carousel view model
    ///
    /// This environment value provides access to the `DiscoveryCarouselViewModeling` protocol
    /// implementation, which handles model discovery operations including fetching recommended
    /// models and latest models from communities.
    ///
    /// ## Example Usage
    /// ```swift
    /// struct DiscoveryView: View {
    ///     @Environment(\.discoveryCarousel) private var viewModel
    ///     @State private var recommendedModels: [DiscoveredModel] = []
    ///
    ///     var body: some View {
    ///         List(recommendedModels) { model in
    ///             Text(model.name)
    ///         }
    ///         .task {
    ///             do {
    ///                 recommendedModels = try await viewModel.recommendedModels()
    ///             } catch {
    ///                 // Handle error
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var discoveryCarousel: DiscoveryCarouselViewModeling =
        PreviewDiscoveryCarouselViewModel()

    /// Environment value for accessing the model actions ViewModel
    ///
    /// This ViewModel provides centralized model state management across the application,
    /// handling the mapping between DiscoveredModel and Model entities.
    ///
    /// ## Usage
    /// ```swift
    /// struct ModelButton: View {
    ///     @Environment(\.modelActionsViewModel) private var modelActions
    ///     let discoveredModel: DiscoveredModel
    ///
    ///     var body: some View {
    ///         if let state = modelActions.state(for: discoveredModel) {
    ///             // Show appropriate UI based on state
    ///         }
    ///     }
    /// }
    /// ```
    @Entry public var modelActionsViewModel: ModelDownloaderViewModeling =
        PreviewModelActionsViewModel()

    /// Environment value for accessing remote model listings.
    @Entry public var remoteModelsViewModel: RemoteModelsViewModeling =
        PreviewRemoteModelsViewModel()

    /// Environment value for accessing the onboarding coordinator
    ///
    /// This coordinator manages background model downloads during the onboarding flow,
    /// providing progress updates and completion status.
    ///
    /// ## Usage
    /// ```swift
    /// struct OnboardingView: View {
    ///     @Environment(\.onboardingCoordinator) private var coordinator
    ///
    ///     var body: some View {
    ///         ProgressView(value: coordinator.overallProgress)
    ///             .task {
    ///                 // Monitor download progress
    ///             }
    ///     }
    /// }
    /// ```
    @Entry public var onboardingCoordinator: OnboardingCoordinating?
}

// MARK: - ViewModels Integration

private struct ViewInteractionControllerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: ViewInteractionController = .init()
}
