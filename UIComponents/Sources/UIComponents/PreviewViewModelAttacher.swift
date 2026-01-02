import Abstractions
import Foundation
import OSLog

/// Default view model implementation for attaching functionality in previews
internal final actor PreviewViewModelAttacher: ViewModelAttaching {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func delete(file: UUID) {
        logger.warning("Default view model - Deleting file: \(file)")
    }

    func process(file: URL, chatId: UUID) {
        logger.warning("Default view model - Processing file: \(file) in chat: \(chatId)")
    }

    func show(error: Error) {
        logger.warning("Default view model - Showing error: \(error)")
    }
}

internal final actor PreviewNotifier: ViewModelNotifying {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func markNotificationAsRead(_ notification: UUID) {
        logger.warning("Default view model - markNotificationAsRead: \(notification)")
    }

    func showMessage(_ message: String) {
        logger.warning("Default view model - showMessage: \(message)")
    }
}

/// Default view model implementation for generation functionality in previews
internal final actor PreviewGenerator: ViewModelGenerating {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func load(chatId: UUID) {
        logger.warning("Default view model - Load chat: \(chatId)")
    }

    func unload() {
        logger.warning("Default view model - Unload called")
    }

    func generate(prompt: String, overrideAction: Abstractions.Action?) {
        logger.warning(
            "Default view model - Generating with: \(prompt), \(String(describing: overrideAction))"
        )
    }

    func stop() {
        logger.warning("Default view model - Stop called")
    }

    func modify(chatId: UUID, modelId: UUID) {
        logger.warning("Default view model - Modifying chatId: \(chatId), modelId: \(modelId)")
    }

    func modelWasUnloaded(id: UUID) {
        logger.warning("Default view model - Model was unloaded: \(id)")
    }
}

/// Default view model implementation for image handling in previews
internal final actor PreviewImageHandler: ViewModelImaging {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    @MainActor
    func savePlatformImage(_: Abstractions.PlatformImage) {
        logger.warning("Default view model - Save image called")
    }

    @MainActor
    func sharePlatformImage(_: Abstractions.PlatformImage) {
        logger.warning("Default view model - Share image called")
    }

    @MainActor
    func copyPlatformImage(_: Abstractions.PlatformImage) {
        logger.warning("Default view model - Copy was called")
    }
}

/// Interaction controller to mediate between views
@preconcurrency
@MainActor
public final class ViewInteractionController {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    @MainActor var removeFocus: (() -> Void)?
    @MainActor var focus: (() -> Void)?
    @MainActor var scrollToBottom: (() -> Void)?

    deinit {
        logger.warning("ViewInteractionController deallocated")
    }
}

internal final actor PreviewReviewViewModel: ReviewPromptManaging {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func recordPositiveAction() {
        logger.warning("Default view model - recordPositiveAction called")
    }

    @MainActor var shouldAskForReview: Bool = false

    func reviewRequested() {
        logger.warning("Default view model - reviewRequested called")
    }

    func userRequestedLater() {
        logger.warning("Default view model - userRequestedLater called")
    }
}

internal final actor PreviewAudioGenerator: AudioViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func say(_ text: String) { logger.warning("Default view model - say called \(text)") }
    func listen(generator _: ViewModelGenerating) async {
        logger.warning("Default view model - listen called)")
    }

    func stopListening() { logger.warning("Default view model - stopListening") }

    var talkModeState: TalkModeState { .idle }
    var wakePhrase: String { "hey think" }
    var isWakeWordEnabled: Bool { true }
    var isTalkModeEnabled: Bool { false }

    func startTalkMode(generator _: ViewModelGenerating) async {
        logger.warning("Default view model - startTalkMode")
    }

    func stopTalkMode() async {
        logger.warning("Default view model - stopTalkMode")
    }

    func updateWakePhrase(_ phrase: String) async {
        logger.warning("Default view model - updateWakePhrase \(phrase)")
    }

    func setWakeWordEnabled(_ enabled: Bool) async {
        logger.warning("Default view model - setWakeWordEnabled \(enabled)")
    }
}

internal final actor PreviewNodeModeViewModel: NodeModeViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    var isEnabled: Bool { false }
    var isRunning: Bool { false }
    var port: Int { 9876 }
    var authToken: String? { nil }

    func refresh() async {
        logger.warning("Default view model - refresh node mode")
    }

    func setEnabled(_ enabled: Bool) async {
        logger.warning("Default view model - setEnabled \(enabled)")
    }

    func updatePort(_ port: Int) async {
        logger.warning("Default view model - updatePort \(port)")
    }

    func updateAuthToken(_ token: String?) async {
        logger.warning("Default view model - updateAuthToken \(token ?? "")")
    }
}

internal final actor PreviewPluginApprovalViewModel: PluginApprovalViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    private var internalPlugins: [PluginCatalogEntry] = []

    var plugins: [PluginCatalogEntry] { internalPlugins }
    var isLoading: Bool { false }
    var errorMessage: String? { nil }

    func loadPlugins() async {
        await Task.yield()
        logger.warning("Default view model - loadPlugins called")
    }

    func approve(pluginId: String) async {
        await Task.yield()
        logger.warning("Default view model - approve called for \(pluginId)")
    }

    func deny(pluginId: String) async {
        await Task.yield()
        logger.warning("Default view model - deny called for \(pluginId)")
    }
}
