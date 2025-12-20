import SwiftUI

/// Protocol for view models that handle platform image operations
public protocol ViewModelImaging: Actor {
    /// Saves a platform image to the device
    /// - Parameter img: The platform image to save
    @MainActor
    func savePlatformImage(_ img: PlatformImage)
    /// Shares a platform image using the system share sheet
    /// - Parameter img: The platform image to share
    @MainActor
    func sharePlatformImage(_ img: PlatformImage)
    /// Copies a platform image to the clipboard
    /// - Parameter img: The platform image to copy
    @MainActor
    func copyPlatformImage(_ img: PlatformImage)
}

// MARK: - Platform Image Typealias & Helpers

#if os(iOS) || os(visionOS)
/// Platform-specific image type alias for iOS and visionOS
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
/// Platform-specific image type alias for macOS
public typealias PlatformImage = NSImage
#endif
