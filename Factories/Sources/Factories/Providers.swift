import Abstractions
import AgentOrchestrator
import AudioGenerator
import ContextBuilder
import Database
import ImageGenerator
import LLamaCPP
import MLXSession
import ModelDownloader
import SwiftData
import SwiftUI
import UIComponents
import ViewModels

/// Providers namespace for SwiftUI view modifiers
public enum Providers {}

// MARK: - Generator Provider

public struct GeneratorProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.generator,
                ViewModelGenerator(
                    orchestrator: AgentOrchestratorFactory.shared(
                        database: database,
                        mlxSession: MLXSessionFactory.create(),
                        ggufSession: LlamaCPPFactory.createSession(),
                        modelDownloader: ModelDownloader.shared
                    ),
                    database: database
                )
            )
    }
}

extension View {
    public func withGenerator() -> some View {
        modifier(GeneratorProvider())
    }
}

// MARK: - ChatViewModel Provider

public struct ChatViewModelProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.chatViewModel,
                ChatViewModel(
                    database: database
                )
            )
    }
}

extension View {
    public func withChatViewModel() -> some View {
        modifier(ChatViewModelProvider())
    }
}

// MARK: - ImageHandler Provider

public struct ImageHandlerProvider: ViewModifier {
    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.imageHandler, ImageViewModel())
    }
}

extension View {
    public func withImageHandler() -> some View {
        modifier(ImageHandlerProvider())
    }
}

// MARK: - NotificationViewModel Provider

public struct NotificationViewModelProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.notificationViewModel,
                NotificationViewModel(
                    database: database
                )
            )
    }
}

extension View {
    /// Adds notification view model to the view environment
    /// - Returns: The view with notification view model configured
    public func withNotificationViewModel() -> some View {
        modifier(NotificationViewModelProvider())
    }
}

// MARK: - Attacher Provider

public struct AttacherProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.attacher,
                ViewModelAttacher(
                    database: database
                )
            )
    }
}

extension View {
    public func withAttacher() -> some View {
        modifier(AttacherProvider())
    }
}

// MARK: - AppViewModel Provider

public struct AppViewModelProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        let appViewModel: AppViewModel = AppViewModel(
            database: database,
            modelDownloaderViewModel: ModelDownloaderViewModel(
                database: database,
                modelDownloader: ModelDownloader(),
                communityExplorer: CommunityModelsExplorer()
            )
        )

        return content
            .environment(\.appViewModel, appViewModel)
    }
}

extension View {
    public func withAppViewModel() -> some View {
        modifier(AppViewModelProvider())
    }
}

// MARK: - Reviews

public struct ReviewRequestProvider: ViewModifier {
    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.reviewPromptViewModel, ReviewPromptViewModel())
    }
}

extension View {
    public func withReviewRequester() -> some View {
        modifier(ReviewRequestProvider())
    }
}

// MARK: - AudioGenerator

public struct AudioGeneratorProvider: ViewModifier {
    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.audioViewModel,
                AudioViewModel(
                    audio: AudioEngine(),
                    speech: SpeechRecognizer()
                )
            )
    }
}

extension View {
    public func withAudioGenerator() -> some View {
        modifier(AudioGeneratorProvider())
    }
}

// MARK: - DiscoveryCarousel Provider

public struct DiscoveryCarouselViewModelProvider: ViewModifier {
    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.discoveryCarousel,
                DiscoveryCarouselViewModel(
                    communityExplorer: CommunityModelsExplorer(),
                    deviceChecker: DeviceCompatibilityChecker(),
                    vramCalculator: VRAMCalculator()
                )
            )
    }
}

extension View {
    public func withDiscoveryCarousel() -> some View {
        modifier(DiscoveryCarouselViewModelProvider())
    }
}

// MARK: - ModelActions Provider

public struct ModelActionsViewModelProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.modelActionsViewModel,
                ModelDownloaderViewModel(
                    database: database,
                    modelDownloader: ModelDownloader(),
                    communityExplorer: CommunityModelsExplorer()
                )
            )
    }
}

extension View {
    public func withModelActions() -> some View {
        modifier(ModelActionsViewModelProvider())
    }
}

// MARK: - OnboardingCoordinator Provider

public struct OnboardingCoordinatorProvider: ViewModifier {
    @Environment(\.database)
    private var database: DatabaseProtocol

    @Environment(\.modelActionsViewModel)
    private var modelDownloaderViewModel: ModelDownloaderViewModeling

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        content
            .environment(
                \.onboardingCoordinator,
                OnboardingCoordinator(
                    modelDownloaderViewModel: modelDownloaderViewModel,
                    database: database
                ) as OnboardingCoordinating
            )
    }
}

extension View {
    public func withOnboardingCoordinator() -> some View {
        modifier(OnboardingCoordinatorProvider())
    }
}
