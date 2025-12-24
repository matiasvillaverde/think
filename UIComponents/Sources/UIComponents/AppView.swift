import Abstractions
import Database
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

public struct AppView: View {
    @Environment(\.notificationViewModel)
    private var notificationViewModel: ViewModelNotifying

    @Environment(\.appViewModel)
    private var appViewModel: AppViewModeling

    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    #if os(iOS)
    @Environment(\.scenePhase)
    private var scenePhase: ScenePhase
    #endif

    @Query(
        filter: #Predicate<NotificationAlert> { $0.isRead == false },
        animation: .easeInOut
    )
    private var notifications: [NotificationAlert]

    @Binding var selectedPersonality: Personality?
    @State private var toast: Toast?
    @State private var isPerformingDelete: Bool = false
    @State private var isInitialized: Bool = false
    @State private var appFlowState: AppFlowState = .onboardingWelcome
    @State private var onboardingCoordinator: OnboardingCoordinating?
    private let animationDuration: Double = 0.3

    public init(selectedPersonality: Binding<Personality?>) {
        _selectedPersonality = selectedPersonality
    }

    public var body: some View {
        Group {
            if !isInitialized {
                loadingView
            } else {
                switch appFlowState {
                case .onboardingWelcome:
                    OnboardingWelcomeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .onboardingFeatures:
                    OnboardingFeaturesView()
                        .environment(\.onboardingCoordinator, onboardingCoordinator)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .welcomeModelSelection:
                    welcomeView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .mainApp:
                    mainView
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: appFlowState)
        .toastView(toast: $toast)
        .task {
            await initializeApp()
        }
        .task {
            await monitorAppFlowState()
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    try? await UNUserNotificationCenter.current().setBadgeCount(0)
                }
            }
        }
        #endif
        .onChange(of: notifications) { _, newNotifications in
            handleNotifications(newNotifications)
        }
    }

    @ViewBuilder private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
    }

    @ViewBuilder private var welcomeView: some View {
        WelcomeView { modelId in
            Task { @MainActor in
                do {
                    try await appViewModel.setupInitialChat(with: modelId)
                    await appViewModel.completeOnboarding()
                } catch {
                    toast = Toast(style: .error, message: error.localizedDescription)
                }
            }
        }
    }

    @ViewBuilder private var mainView: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                SideView(
                    isPerformingDelete: $isPerformingDelete,
                    selectedPersonality: $selectedPersonality
                )
                SettingsButton()
                    .padding()
            }
        } detail: {
            NavigationStack {
                if let personality = selectedPersonality, let chat = personality.chat {
                    ChatView(chat: chat)
                } else if selectedPersonality != nil {
                    // Personality selected but no chat yet - show loading
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Select a personality to start", bundle: .module)
                        .foregroundColor(Color.textPrimary)
                }
            }
        }
        .accentColor(Color.marketingSecondary)
    }

    private func initializeApp() async {
        #if os(iOS)
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        #endif
        await appViewModel.initializeDatabase()
        await appViewModel.resumeBackgroundDownloads()

        let initialState: AppFlowState = await appViewModel.appFlowState

        await MainActor.run {
            appFlowState = initialState
            isInitialized = true
        }
    }

    private func monitorAppFlowState() async {
        while !Task.isCancelled {
            let currentState: AppFlowState = await appViewModel.appFlowState
            if currentState != appFlowState {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: animationDuration)) {
                        appFlowState = currentState
                    }
                }
            }
            try? await Task.sleep(nanoseconds: OnboardingConstants.stateMonitorNanoseconds)
        }
    }

    private func handleNotifications(_ newNotifications: [NotificationAlert]) {
        if let latestNotification = newNotifications.first {
            switch latestNotification.type {
            case .success:
                toast = Toast(style: .success, message: latestNotification.localizedMessage)

            case .error:
                toast = Toast(style: .error, message: latestNotification.localizedMessage)

            case .warning:
                toast = Toast(style: .warning, message: latestNotification.localizedMessage)

            case .information:
                toast = Toast(style: .info, message: latestNotification.localizedMessage)
            }

            Task(priority: .utility) {
                await notificationViewModel.markNotificationAsRead(latestNotification.id)
            }
        } else if newNotifications.isEmpty {
            toast = nil
        }
    }
}

#Preview {
    @Previewable @State var selectedPersonality: Personality?
    AppView(selectedPersonality: $selectedPersonality)
}
