import UIComponents
import SwiftUI
import Factories
import Database

@main
struct ThinkApp: App {

    /// Localized string so the entire app gets localized
    private let name: String = String(localized: "Think")

    @State private var selectedChat: Chat?

    var body: some Scene {
        WindowGroup {
            AppView(selectedChat: $selectedChat)
                .withDatabase(configuration: .default)
                .withGenerator() // MLX doesn't work on simulators
                .withChatViewModel()
                .withToolValidator()
                .withImageHandler()
                .withNotificationViewModel()
                .withAttacher()
                .withAppViewModel()
                .withReviewRequester()
                .withPluginApprovalViewModel()
                .withAudioGenerator()
                .withDiscoveryCarousel()
                .withModelActions()
                .withOnboardingCoordinator()
        }
    }
}
