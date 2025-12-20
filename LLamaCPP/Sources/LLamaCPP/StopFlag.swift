import Foundation

/// Stop flag that can be shared between actor and non-actor contexts
/// Note: Only one reader (struct) and one writer (actor), so no locking needed
internal final class StopFlag: @unchecked Sendable {
    private var value: Bool = false

    internal init() {
        // Initialize stop flag
    }

    @inline(__always)
    internal func get() -> Bool {
        value
    }

    internal func set(_ newValue: Bool) {
        value = newValue
    }

    internal func reset() {
        value = false
    }

    deinit {
        // Clean up if needed
    }
}
