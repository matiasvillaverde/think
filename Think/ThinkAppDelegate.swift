#if canImport(UIKit)
import UIKit
import ViewModels
import Factories
import Abstractions
import Database

/// App delegate to handle background download events
final class ThinkAppDelegate: NSObject, UIApplicationDelegate {

    /// Handle background URLSession events
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task {
            // Use the singleton database instance that was created by the SwiftUI environment
            // This ensures we use the same database instance throughout the app
            let database = Database.instance(configuration: .default)
            let modelDownloaderViewModel = ModelDownloaderViewModelFactory.create(database: database)
            await modelDownloaderViewModel.handleBackgroundDownloadCompletion(
                identifier: identifier,
                completionHandler: completionHandler
            )
        }
    }
}
#endif
