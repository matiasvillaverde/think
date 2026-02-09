import Foundation

#if DEBUG

import OSLog

@inline(__always)
internal func logPrint(_ s: String) {
    Logger(subsystem: "AudioGenerator", category: "Debug").debug("\(s, privacy: .public)")
}

#else

@inline(__always)
internal func logPrint(_: String) {
    // No-op in release builds
}

#endif
