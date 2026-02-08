import CoreGraphics
import Foundation
import SwiftData

@Model
@DebugDescription
public final class ImageAttachment: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set)  var createdAt: Date = Date()

    // MARK: - Metadata

    @Attribute(.externalStorage)
    public internal(set) var image: Data

    /// The prompt it was used to create the image
    @Attribute()
    public internal(set) var prompt: String?

    /// Text describing what the image has inside.
    @Attribute()
    public private(set) var content: String?

    // MARK: - Relationships

    /// The configuration used to generate the image.
    ///
    /// Image attachments should not own the diffusion configuration. The configuration is owned by the chat.
    /// If an attachment is deleted (e.g. clearing chat history), we must not delete the configuration and
    /// leave the chat with a dangling reference.
    @Relationship(deleteRule: .nullify)
    public internal(set) var configuration: DiffusorConfiguration?

    // MARK: - Initialization

    init(
        image: Data,
        prompt: String? = nil,
        content: String? = nil,
        configuration: DiffusorConfiguration? = nil
    ) {
        self.image = image
        self.prompt = prompt
        self.content = content
        self.configuration = configuration
    }
}

#if DEBUG
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
extension ImageAttachment {
    @MainActor public static var preview: ImageAttachment = {
        // Create a sample image data that works in both UIKit and AppKit
        let imageData = createSampleImageData()

        return ImageAttachment(
            image: imageData,
            prompt: "Sample prompt for image generation",
            content: "A solid blue square image",
            configuration: DiffusorConfiguration.preview
        )
    }()

    @preconcurrency
    @MainActor
    public static func preview(
        prompt: String? = "Sample prompt",
        content: String? = "Sample content description",
        configuration: DiffusorConfiguration? = DiffusorConfiguration.preview
    ) -> ImageAttachment {
        ImageAttachment(
            image: createSampleImageData(),
            prompt: prompt,
            content: content,
            configuration: configuration
        )
    }

    // Helper function to load image data from asset catalog
    private static func createSampleImageData() -> Data {
        let size = CGSize(width: 64, height: 64)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return Data()
        }

        context.setFillColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: size))

        guard let image = context.makeImage() else {
            return Data()
        }

        #if canImport(UIKit)
        let uiImage = UIImage(cgImage: image)
        return uiImage.jpegData(compressionQuality: 0.8) ?? Data()

        #elseif canImport(AppKit)

        let nsImage = NSImage(cgImage: image, size: size)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return Data()
        }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) ?? Data()

        #else
        return Data()
        #endif
    }
}
#endif
