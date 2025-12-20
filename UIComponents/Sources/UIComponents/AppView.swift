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

    @Binding var selectedChat: Chat?
    @State private var toast: Toast?
    @State private var isPerformingDelete: Bool = false
    @State private var isInitialized: Bool = false
    @State private var appFlowState: AppFlowState = .onboardingWelcome
    @State private var onboardingCoordinator: OnboardingCoordinating?
    private let animationDuration: Double = 0.3

    public init(selectedChat: Binding<Chat?>) {
        _selectedChat = selectedChat
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
            // Clear notification badge when app opens
            #if os(iOS)
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
            #endif
            await appViewModel.initializeDatabase()
            await appViewModel.resumeBackgroundDownloads()

            // Get the initial app flow state
            let initialState: AppFlowState = await appViewModel.appFlowState

            // Create OnboardingCoordinator if we're in onboarding
            if initialState == .onboardingWelcome || initialState == .onboardingFeatures {
                // OnboardingCoordinator will be created and injected by the app
                // For now, we'll use the environment value if available
            }

            await MainActor.run {
                appFlowState = initialState
                isInitialized = true
            }
        }
        .task {
            // Monitor app flow state changes from the view model
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
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    // Clear notification badge when app becomes active
                    try? await UNUserNotificationCenter.current().setBadgeCount(0)
                }
            }
        }
        #endif
        .onChange(of: notifications) { _, newNotifications in
            // Check if we have a new notification
            if let latestNotification = newNotifications.first {
                // Create toast based on notification type
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

                // Mark the notification as read
                Task(priority: .utility) {
                    await notificationViewModel.markNotificationAsRead(latestNotification.id)
                }
            } else if newNotifications.isEmpty {
                // If there are no notifications, clear the toast
                toast = nil
            }
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
                    selectedChat: $selectedChat
                )
                SettingsButton()
                    .padding()
            }
        } detail: {
            NavigationStack {
                if let chat = selectedChat {
                    ChatView(chat: chat)
                } else {
                    Text("Select a chat to start", bundle: .module)
                        .foregroundColor(Color.textPrimary)
                }
            }
        }
        .accentColor(Color.marketingSecondary)
    }
}

#Preview {
    @Previewable @State var selectedChat: Chat?
    AppView(selectedChat: $selectedChat)
}
