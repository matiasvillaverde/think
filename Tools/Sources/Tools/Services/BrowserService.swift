import Abstractions
import Foundation
import os

/// Browser service that provides web search capabilities
public struct BrowserService {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "BrowserService")
    /// Initialize a new BrowserService
    public init() {
        Self.logger.debug("Initializing BrowserService")
    }

    /// Register browser tools with the tool manager
    public func registerTools(with manager: ToolManager) async {
        Self.logger.info("Registering browser tools with ToolManager")
        await manager.registerStrategy(BrowserSearchStrategy())
        Self.logger.debug("Browser search strategy registered successfully")
    }
}
