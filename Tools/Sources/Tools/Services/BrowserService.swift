import Abstractions
import Foundation
import os

/// Browser service that provides web search capabilities
public struct BrowserService {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "BrowserService")
    private let searchStrategy: BrowserSearchStrategy
    /// Initialize a new BrowserService
    public init() {
        Self.logger.debug("Initializing BrowserService")
        self.searchStrategy = BrowserSearchStrategy()
    }

    /// Internal initializer for injecting a custom strategy (testing)
    internal init(searchStrategy: BrowserSearchStrategy) {
        Self.logger.debug("Initializing BrowserService with custom strategy")
        self.searchStrategy = searchStrategy
    }

    /// Register browser tools with the tool manager
    public func registerTools(with manager: ToolManager) async {
        Self.logger.info("Registering browser tools with ToolManager")
        await manager.registerStrategy(searchStrategy)
        Self.logger.debug("Browser search strategy registered successfully")
    }
}
