import Foundation
import OSLog
#if canImport(Cocoa)
    import Cocoa
#endif
#if canImport(UIKit)
    import MessageUI
    import UIKit
#endif
// swiftlint:disable line_length

/// A utility for reporting bugs with comprehensive app and device information
public enum BugReporter {
    // MARK: - Configuration

    /// Email address to send bug reports to
    private static let supportEmail: String = "contact@thinkfreely.chat"

    /// Subject line for bug report emails
    private static let bugReportSubject: String = "Bug Report"

    /// How far back to collect logs (in hours)
    private static let logHistoryHours: TimeInterval = 24

    /// Maximum number of log entries to include
    private static let maxLogEntries: Int = 1_000

    private static let timeFormatter: Double = 3_600

    // MARK: - Public Interface

    /// Attempts to send a bug report via email
    /// - Returns: True if email could be launched, false otherwise
    @MainActor
    @discardableResult
    static func sendBugReport() -> Bool {
        guard let mailURL = composeEmailURL() else {
            return false
        }

        #if os(iOS) || os(visionOS)
            if UIApplication.shared.canOpenURL(mailURL) {
                UIApplication.shared.open(mailURL)
                return true
            }
        #elseif os(macOS)
            NSWorkspace.shared.open(mailURL)
        #endif
        return true
    }

    #if os(iOS) || os(visionOS)
        /// Presents mail composer if available (better than URL method on iOS)
        /// - Parameter viewController: The view controller to present from
        /// - Returns: True if presented successfully, false otherwise
        @MainActor
        static func presentMailComposer(from viewController: UIViewController) -> Bool {
            guard MFMailComposeViewController.canSendMail() else {
                // Fall back to URL method
                return sendBugReport()
            }

            let composer: MFMailComposeViewController = MFMailComposeViewController()
            composer.setToRecipients([supportEmail])
            composer.setSubject(bugReportSubject)

            let deviceInfo: String = gatherDeviceInfo()
            let logs: String = gatherLogs()

            let emailBody: String = """
            Bug Report

            Please describe the issue below:


            --- Device Information ---
            \(deviceInfo)

            --- Logs ---
            \(logs)
            """

            composer.setMessageBody(emailBody, isHTML: false)
            composer.mailComposeDelegate = EmailComposerDelegate.shared

            viewController.present(composer, animated: true)
            return true
        }

        /// Delegate for mail composer
        @MainActor
        private class EmailComposerDelegate: NSObject,
            @preconcurrency MFMailComposeViewControllerDelegate {
            static let shared: EmailComposerDelegate = .init()

            deinit {
                // Cleanup handled automatically
            }

            @MainActor
            func mailComposeController(
                _ controller: MFMailComposeViewController,
                didFinishWith _: MFMailComposeResult,
                error _: Error?
            ) {
                controller.dismiss(animated: true)
            }
        }
    #endif

    // MARK: - Email Composition

    /// Creates a mailto: URL with all bug report information
    /// - Returns: URL to launch email client, or nil if creation failed
    @MainActor
    static func composeEmailURL() -> URL? {
        let deviceInfo: String = gatherDeviceInfo()
        let logs: String = gatherLogs()

        let body: String = String(
            localized: """
            Bug Report

            Please describe the issue below:


            --- Device Information ---
            \(deviceInfo)

            --- Logs ---
            \(logs)
            """,
            bundle: .module,
            comment: "Email body for bug report that adds device information and logs"
        )

        let subjectEncoded: String = bugReportSubject.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        let bodyEncoded: String = body.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""

        let urlString: String
            = "mailto:\(supportEmail)?subject=\(subjectEncoded)&body=\(bodyEncoded)"

        return URL(string: urlString)
    }

    /// Creates a formatted string with logs that can be shared via other means
    /// - Returns: String with all logs and device information
    @MainActor
    static func generateReportText() -> String {
        let deviceInfo: String = gatherDeviceInfo()
        let logs: String = gatherLogs()

        return """
        Bug Report

        --- Device Information ---
        \(deviceInfo)

        --- Logs ---
        \(logs)
        """
    }

    // MARK: - Device Information

    /// Gathers detailed device information
    /// - Returns: Formatted string with device details
    @MainActor
    static func gatherDeviceInfo() -> String {
        var deviceInfo: String = ""

        // App information
        let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "Unknown"
        let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"]
            as? String ?? "Unknown"
        let bundleId: String = Bundle.main.bundleIdentifier ?? "Unknown"

        deviceInfo += "App Version: \(appVersion) (\(buildNumber))\n"
        deviceInfo += "Bundle ID: \(bundleId)\n"

        // Device model & OS
        #if os(iOS)
            deviceInfo += "Device: \(UIDevice.current.model)\n"
            deviceInfo += "System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n"

            // Additional iOS device info
            let screenSize: CGSize = UIScreen.main.bounds.size
            deviceInfo
                += "Screen: \(screenSize.width) x \(screenSize.height), Scale: \(UIScreen.main.scale)\n"
            deviceInfo += "Idiom: \(Self.description(for: UIDevice.current.userInterfaceIdiom))\n"

        #elseif os(macOS)
            deviceInfo += "Device: Mac\n"
            deviceInfo += "System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"

            // Additional Mac info
            let screenSize: CGSize = NSScreen.main?.frame.size ?? .zero
            deviceInfo += "Screen: \(screenSize.width) x \(screenSize.height)\n"
        #endif

        // Memory information
        let physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        deviceInfo += "Physical Memory: \(physicalMemory)"

        // Processor information
        let processorCount: Int = ProcessInfo.processInfo.processorCount
        deviceInfo += "Processor Count: \(processorCount)\n"

        // Locale/region information
        let locale: Locale = Locale.current
        deviceInfo += "Locale: \(locale.identifier)\n"

        // Timezone information
        let timezone: TimeZone = TimeZone.current
        deviceInfo += "Timezone: \(timezone.identifier) (GMT\(Double(timezone.secondsFromGMT()) / Self.timeFormatter))\n"

        // Date and time of report
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        deviceInfo += "Report Date: \(dateFormatter.string(from: Date()))\n"

        return deviceInfo
    }

    // MARK: - Log Collection

    /// Gathers logs from the system's unified logging system
    /// - Returns: Formatted string with logs
    static func gatherLogs() -> String {
        var logOutput: String = "No logs available"

        do {
            // Create OSLogStore for the current process
            let store: OSLogStore = try OSLogStore(scope: .currentProcessIdentifier)

            // Get logs from the configured time period
            let date: Date = Date().addingTimeInterval(-logHistoryHours * Self.timeFormatter)
            let position: OSLogPosition = store.position(date: date)

            // Get the app's bundle identifier for filtering
            let bundleID: String = Bundle.main.bundleIdentifier ?? ""

            // Get and format log entries
            let logEntries: ArraySlice<String> = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == bundleID }
                .map { entry -> String in
                    // Format date
                    let formatter: DateFormatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                    let timestamp: String = formatter.string(from: entry.date)

                    // Get log level as string
                    let level: String = logLevelString(from: entry.level)

                    // Format the log entry
                    return "[\(timestamp)] [\(level)] [\(entry.subsystem):\(entry.category)] \(entry.composedMessage)"
                }
                // Enforce maximum to avoid huge emails
                .prefix(maxLogEntries)

            if logEntries.isEmpty {
                logOutput = "No logs found for this application in the last \(Int(logHistoryHours)) hours."
            } else {
                let entriesArray: [String] = Array(logEntries)
                logOutput = entriesArray.joined(separator: "\n")

                // Add note if logs were truncated
                if entriesArray.count >= maxLogEntries {
                    logOutput += "\n\n--- Log truncated (showing most recent \(maxLogEntries) entries) ---"
                }
            }
        } catch {
            logOutput = "Failed to retrieve system logs: \(error.localizedDescription)"
        }

        return logOutput
    }

    // MARK: - Helper Methods

    /// Converts OSLogEntryLog.Level to a human-readable string
    /// - Parameter level: Log level from OSLogEntryLog
    /// - Returns: String representation of the log level
    private static func logLevelString(from level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined:
            return "UNDEFINED"

        case .debug:
            return "DEBUG"

        case .info:
            return "INFO"

        case .notice:
            return "NOTICE"

        case .error:
            return "ERROR"

        case .fault:
            return "FAULT"

        @unknown default:
            return "UNKNOWN"
        }
    }

    #if os(iOS) || os(visionOS)
        private static func description(for idiom: UIUserInterfaceIdiom) -> String {
            switch idiom {
            case .phone:
                return "iPhone"

            case .pad:
                return "iPad"

            case .tv:
                return "TV"

            case .carPlay:
                return "CarPlay"

            case .mac:
                return "Mac"

            case .vision:
                return "Vision"

            case .unspecified:
                return "Unspecified"

            @unknown default:
                return "Unknown"
            }
        }
    #endif
}

// swiftlint:enable line_length
