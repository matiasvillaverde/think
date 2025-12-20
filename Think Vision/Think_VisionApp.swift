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
                .withDatabase()
                .withGenerator() // MLX doesn't work on simulators
                .withChatViewModel()
                .withImageHandler()
                .withNotificationViewModel()
                .withAttacher()
                .withAppViewModel()
                .withReviewRequester()
                .withAudioGenerator()
                .withDiscoveryCarousel()
                .withModelActions()
                .withOnboardingCoordinator()
        }
    }
}
