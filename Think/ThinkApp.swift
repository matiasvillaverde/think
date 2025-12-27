import UIComponents
import SwiftUI
import Factories
import Database

@main
struct ThinkApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ThinkAppDelegate.self) var appDelegate
    #endif

    /// Localized string so the entire app gets localized
    private let name: String = String(localized: "Think")

    @State private var selectedPersonality: Personality?

    var body: some Scene {
        WindowGroup {
            AppView(selectedPersonality: $selectedPersonality)
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
                .withRemoteModelsViewModel()
                .withOnboardingCoordinator()
        }

        #if os(macOS)
        Window("Discover AI Models", id: "discovery") {
            DiscoveryWindow(selectedPersonality: $selectedPersonality)
                .withDatabase()
#if !targetEnvironment(simulator)
                .withGenerator() // MLX doesn't work on simulators
#endif
                .withChatViewModel()
                .withNotificationViewModel()
                .withAppViewModel()
                .withDiscoveryCarousel()
                .withModelActions()
                .withRemoteModelsViewModel()
        }
        .defaultSize(width: 900, height: 700)

        Window("Analytics Dashboard", id: "analytics") {
            AnalyticsNavigationView()
                .withDatabase()
                .withChatViewModel()
                .withNotificationViewModel()
                .withAppViewModel()
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .withDatabase()
                .withChatViewModel()
                .withReviewRequester()
        }
        .defaultSize(width: 700, height: 600)
        #endif
    }
}
