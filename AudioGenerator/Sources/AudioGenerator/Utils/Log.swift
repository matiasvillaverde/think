import Foundation

#if DEBUG

@inline(__always)
internal func logPrint(_ s: String) {
    print(s)
}

#else

@inline(__always)
internal func logPrint(_: String) {
    // No-op in release builds
}

#endif
