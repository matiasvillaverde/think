import Abstractions
import Database
import Foundation
import SwiftUI

// MARK: - SwiftUI Integration

// Environment key for database instance (no configuration)
public struct DatabaseKey: EnvironmentKey {
    public static let defaultValue: DatabaseProtocol = Database.instance(configuration: .default)
}

extension EnvironmentValues {
    var database: DatabaseProtocol {
        self[DatabaseKey.self]
    }
}

// Simple view modifier that provides the default database
public struct DatabaseProvider: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .modelContainer(Database.instance(configuration: .default).modelContainer)
    }
}

// Convenience extension
extension View {
    /// Adds the default database configuration to the view environment
    /// - Returns: The view with database environment configured
    public func withDatabase() -> some View {
        modifier(DatabaseProvider())
    }
}
