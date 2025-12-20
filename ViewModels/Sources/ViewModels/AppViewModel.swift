// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
import OSLog

/// A view model responsible for managing application-wide operations.
public final actor AppViewModel: AppViewModeling {
    // MARK: - Properties

    /// Database interface for persistence operations
    private let database: DatabaseProtocol

    /// Model downloader view model for resuming background downloads
    private let _modelDownloaderViewModel: ModelDownloaderViewModeling

    /// Public accessor for model downloader view model (needed for AppDelegate)
    nonisolated public var modelDownloaderViewModel: ModelDownloaderViewModeling {
        _modelDownloaderViewModel
    }

    /// Logger instance for diagnostic information
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: AppViewModel.self)
    )

    /// The current app flow state
    internal var internalAppFlowState: AppFlowState = .onboardingWelcome

    /// The current state of the application flow
    public var appFlowState: AppFlowState {
        internalAppFlowState
    }

    /// The target screen that should be shown after initialization
    private var _targetScreen: AppScreen?
    /// The target screen determined during initialization
    public var targetScreen: AppScreen {
        // If we haven't initialized yet, return welcome as default
        guard let screen = _targetScreen else {
            logger.warning(
                "Target screen accessed before initialization - returning welcome as default"
            )
            return .welcome
        }
        return screen
    }

    // MARK: - Lifecycle

    /// Initializes a new application view model.
    /// - Parameters:
    ///   - database: The database implementation for persistence operations.
    ///   - modelDownloaderViewModel: The model downloader view model for managing downloads.
    public init(database: DatabaseProtocol, modelDownloaderViewModel: ModelDownloaderViewModeling) {
        self.database = database
        self._modelDownloaderViewModel = modelDownloaderViewModel
        logger.info(
            "AppViewModel initialized with database type: \(String(describing: type(of: database)))"
        )
        Self.incrementLaunchCount()
    }

    // MARK: - Public Methods

    /// Navigates to the next state in the application flow
    public func navigateToNextState() {
        if let nextState = internalAppFlowState.nextState {
            logger.info("Navigating from \(String(describing: self.internalAppFlowState)) to \(String(describing: nextState))")
            internalAppFlowState = nextState
        } else {
            logger.debug("Already at final state: \(String(describing: self.internalAppFlowState))")
        }
    }

    /// Completes the onboarding process and navigates directly to the main app
    public func completeOnboarding() {
        logger.info("Completing onboarding - navigating to main app")
        internalAppFlowState = .mainApp
    }

    /// Initializes the application database.
    ///
    /// This method should be called during application startup to ensure the database
    /// is properly initialized before any other database operations are performed.
    public func initializeDatabase() async {
        logger.debug("Beginning database initialization")

        do {
            let result: AppInitializationResult = try await database.execute(AppCommands.Initialize())
            _targetScreen = result.targetScreen

            // Set initial app flow state based on target screen
            switch result.targetScreen {
            case .welcome:
                internalAppFlowState = .onboardingWelcome

            case .chat:
                internalAppFlowState = .mainApp
            }

            logger.info(
                "Database successfully initialized with AppInitialization - user: \(result.userId), screen: \(result.targetScreen), appFlowState: \(String(describing: self.internalAppFlowState))"
            )
        } catch {
            logger.error("Failed to initialize database: \(error.localizedDescription)")

            do {
                try await database.write(
                    NotificationCommands.Create(
                        type: .error,
                        message: "Failed to initialize database: \(error.localizedDescription)"
                    )
                )
                logger.debug("Error notification created for database initialization failure")
            } catch {
                logger.fault(
                    "Critical failure: Unable to create error notification: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Resumes any background downloads that were in progress when the app was terminated.
    ///
    /// This method should be called during application startup after the database has been
    /// initialized. It will:
    /// - Resume all persisted background downloads
    /// - Update Model entities in the database with current download progress
    /// - Re-establish active download tracking
    ///
    /// Call this method from:
    /// - `applicationDidFinishLaunching` on macOS
    /// - `application(_:didFinishLaunchingWithOptions:)` on iOS
    /// - `onAppear` of the root view on visionOS
    ///
    /// Example:
    /// ```swift
    /// // In your App delegate or root view
    /// Task {
    ///     await appViewModel.initializeDatabase()
    ///     await appViewModel.resumeBackgroundDownloads()
    /// }
    /// ```
    public func resumeBackgroundDownloads() async {
        logger.info("Resuming background downloads on app launch")
        await _modelDownloaderViewModel.resumeBackgroundDownloads()
    }

    /// Sets up the initial chat with the selected model.
    ///
    /// This method should be called when the user selects a model from the welcome screen.
    /// It creates the first chat using the specified model.
    ///
    /// - Parameter modelId: The UUID of the model to use for the initial chat.
    public func setupInitialChat(with modelId: UUID) async throws {
        logger.info("🎯 Setting up initial chat with model: \(modelId)")

        do {
            // Get the default personality ID
            let defaultPersonalityId: UUID = try await database.read(PersonalityCommands.GetDefault())

            // Create the initial chat with the selected model
            let chatId: UUID = try await database.write(
                ChatCommands.CreateWithModel(
                    modelId: modelId,
                    personalityId: defaultPersonalityId
                )
            )

            logger.info("Initial chat created successfully with ID: \(chatId)")
        } catch {
            logger.error("Failed to setup initial chat: \(error)")
            throw error
        }
    }

    /// Requests notification permissions for download notifications.
    ///
    /// This method requests permission from the user to show notifications when
    /// model downloads complete in the background. The permission dialog is only
    /// shown once per app installation.
    public func requestNotificationPermissions() async {
        logger.info("Requesting notification permissions for download notifications")

        // Request permission through the model downloader
        let granted: Bool = await _modelDownloaderViewModel.requestNotificationPermission()

        logger.info("Notification permission request result: \(granted ? "granted" : "denied")")

        if !granted {
            logger.debug(
                "User declined notification permissions - downloads will complete silently"
            )
        }
    }

    private static func incrementLaunchCount() {
        let launchCountKey: String = "appLaunchCount"
        let userDefaults: UserDefaults = UserDefaults.standard
        let currentCount: Int = userDefaults.integer(forKey: launchCountKey)
        userDefaults.set(currentCount + 1, forKey: launchCountKey)
    }
}
// swiftlint:enable line_length
