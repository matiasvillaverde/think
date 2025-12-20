import Foundation
#if DEBUG
import os.signpost
#endif

/// Performance instrumentation for DEBUG builds only
/// Uses conditional compilation to ensure zero overhead in release builds
internal enum SignpostInstrumentation {
    #if DEBUG
    /// Signpost log for LlamaCPP performance tracking
    internal static let log: OSLog = OSLog(
        subsystem: "com.think.llamacpp",
        category: .pointsOfInterest
    )

    /// Signposter for creating intervals
    internal static let signposter: OSSignposter = OSSignposter(logHandle: log)
    #endif
}
