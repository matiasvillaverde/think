// swiftlint:disable line_length
import Abstractions
import OSLog
import SwiftUI

/// Central place for save/share/copy logic across iOS, visionOS, and macOS.
public final actor ImageViewModel: ViewModelImaging {
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: ImageViewModel.self)
    )

    public init() {
        // Default initialization - no setup required
    }

    /// Saves the `PlatformImage` either to Photos (iOS/visionOS) or Downloads (macOS).
    @preconcurrency
    @MainActor
    public func savePlatformImage(_ img: PlatformImage) {
        #if canImport(UIKit)
        // iOS/visionOS
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)

        // Optional haptic feedback
        #if os(iOS)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        #elseif os(macOS)
        let savePanel: NSSavePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy-HH-mm-ss"
        let formattedDate: String = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "Think-\(formattedDate).png"

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try img.writePNG(to: url)
                    self.logger.info("Image saved to \(url.path, privacy: .public)")
                } catch {
                    self.logger.error("Failed to save: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                self.logger.info("Save panel canceled or failed.")
            }
        }
        #endif
    }

    /// Shares the `PlatformImage` using the appropriate share sheet or service picker.
    @preconcurrency
    @MainActor
    public func sharePlatformImage(_ img: PlatformImage) {
        #if canImport(UIKit)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        guard let data = img.pngData() else {
            logger.error("Failed to convert UIImage to PNG data.")
            return
        }

        let activity: UIActivityViewController = UIActivityViewController(
            activityItems: [data],
            applicationActivities: nil
        )
        if
            let scene: UIWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC: UIViewController = scene.windows.first?.rootViewController {
            activity.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activity, animated: true, completion: nil)
        }

        #elseif canImport(AppKit)
        logger.info("Initiating share on macOS...")

        guard let tiffData = img.tiffRepresentation else {
            logger.error("Failed to get TIFF representation from NSImage.")
            return
        }

        let sharingServicePicker: NSSharingServicePicker = NSSharingServicePicker(items: [tiffData])
        if let window = NSApplication.shared.windows.first?.contentView {
            sharingServicePicker.show(relativeTo: .zero, of: window, preferredEdge: .minY)
        }
        #endif
    }

    /// Copies the `PlatformImage` to the system clipboard.
    @preconcurrency
    @MainActor
    public func copyPlatformImage(_ img: PlatformImage) {
        #if canImport(UIKit)

        UIPasteboard.general.image = img
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        #elseif canImport(AppKit)

        let pasteboard: NSPasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if pasteboard.writeObjects([img]) {
            logger.info("Successfully copied image to clipboard.")
        } else {
            logger.error("Failed to copy image to clipboard.")
        }
        #endif
    }
}

#if os(macOS)
extension NSImage {
    /// Writes the NSImage as a PNG to the specified URL.
    func writePNG(to url: URL) throws {
        guard
            let tiffData: Data = tiffRepresentation,
            let rep: NSBitmapImageRep = NSBitmapImageRep(data: tiffData),
            let pngData: Data = rep.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "NSImageWriteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to PNG"])
        }
        try pngData.write(to: url)
    }
}
#endif
// swiftlint:enable line_length
