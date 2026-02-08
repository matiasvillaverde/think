import Foundation

/// Skip error for tests that require local GGUF model files.
///
/// SwiftTesting treats this as a skip in this repo (see RemoteSession integration tests).
internal struct TestSkip: Error, CustomStringConvertible {
    internal let reason: String

    internal init(_ reason: String) {
        self.reason = reason
    }

    internal var description: String { reason }
}
