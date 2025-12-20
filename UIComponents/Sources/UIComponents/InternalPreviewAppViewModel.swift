import Abstractions
import Foundation
import OSLog

internal final actor InternalPreviewAppViewModel: AppViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    var appFlowState: AppFlowState {
        // swiftlint:disable:next async_without_await
        get async {
            logger.warning("Default view model - appFlowState called")
            return .mainApp
        }
    }

    func navigateToNextState() {
        logger.warning("Default view model - navigateToNextState called")
    }

    func completeOnboarding() {
        logger.warning("Default view model - completeOnboarding called")
    }

    func initializeDatabase() {
        logger.warning("Default view model - initializeDatabase called")
    }

    func resumeBackgroundDownloads() {
        logger.warning("Default view model - resumeBackgroundDownloads called")
    }

    func requestNotificationPermissions() {
        logger.warning("Default view model - requestNotificationPermissions called")
    }

    func ensureDefaultModelExists() {
        logger.warning("Default view model - ensureDefaultModelExists called")
    }

    func setupInitialChat(with modelId: UUID) async {
        await Task.yield()
        logger.warning("Default view model - setupInitialChat called with modelId: \(modelId)")
    }
}
