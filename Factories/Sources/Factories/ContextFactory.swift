import Abstractions
import ContextBuilder
import Database
import Foundation
import Tools

/// Factory for creating Context instances with proper dependencies
public enum ContextFactory {
    /// Create a context builder with tooling support
    /// - Parameter database: The database instance to use (kept for API compatibility)
    /// - Returns: A configured ContextBuilding instance
    public static func createContext(database _: DatabaseProtocol) -> ContextBuilding {
        let toolManager: ToolManager = ToolManager()
        return ContextBuilder(tooling: toolManager)
    }
}
