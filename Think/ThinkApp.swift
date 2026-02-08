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
                .withNodeModeViewModel()
                .withOpenClawInstancesViewModel()
                .withAutomationScheduler()
                .withDiscoveryCarousel()
                .withModelActions()
                .withRemoteModelsViewModel()
                .withOnboardingCoordinator()
        }

        #if os(macOS)
        Window("Discover AI Models", id: "discovery") {
            DiscoveryWindow(selectedPersonality: $selectedPersonality)
                .withDatabase(configuration: .default)
#if !targetEnvironment(simulator)
                .withGenerator() // MLX doesn't work on simulators
#endif
                .withChatViewModel()
                .withToolValidator()
                .withNotificationViewModel()
                .withAppViewModel()
                .withPluginApprovalViewModel()
                .withDiscoveryCarousel()
                .withModelActions()
                .withRemoteModelsViewModel()
                .withOpenClawInstancesViewModel()
        }
        .defaultSize(width: 900, height: 700)

        Window("Analytics Dashboard", id: "analytics") {
            AnalyticsNavigationView()
                .withDatabase(configuration: .default)
                .withChatViewModel()
                .withToolValidator()
                .withNotificationViewModel()
                .withAppViewModel()
                .withPluginApprovalViewModel()
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .withDatabase(configuration: .default)
                .withChatViewModel()
                .withToolValidator()
                .withReviewRequester()
                .withPluginApprovalViewModel()
                .withAudioGenerator()
                .withNodeModeViewModel()
                .withOpenClawInstancesViewModel()
                .withAutomationScheduler()
        }
        .defaultSize(width: 700, height: 600)
        #endif
    }
}
