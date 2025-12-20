// Image.swift
import Abstractions
#if canImport(AppKit)
    import AppKit
#endif
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Converts optional `Data` to a platform-specific image (`UIImage`/`NSImage`).
internal func dataToPlatformImage(_ data: Data?) -> PlatformImage? {
    guard let data else {
        return nil
    }
    #if canImport(UIKit)
        return UIImage(data: data)
    #elseif canImport(AppKit)
        return NSImage(data: data)
    #else
        return nil
    #endif
}

extension Image {
    /// Initializes a SwiftUI `Image` from a platform-specific image.
    init(platformImage: PlatformImage) {
        #if os(iOS) || os(visionOS)
            self.init(uiImage: platformImage)
        #elseif os(macOS)
            self.init(nsImage: platformImage)
        #endif
    }
}

#if os(macOS)
    extension NSImage {
        /// Writes the NSImage as a PNG to the specified URL.
        func writePNG(to url: URL) throws {
            guard
                let tiffData = tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiffData),
                let pngData = rep.representation(using: .png, properties: [:])
            else {
                throw NSError(
                    domain: "NSImageWriteError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to PNG"]
                )
            }
            try pngData.write(to: url)
        }
    }

#endif
