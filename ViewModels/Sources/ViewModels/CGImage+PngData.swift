import CoreImage
import ImageIO

extension CGImage {
    /// Converts a CGImage to PNG data
    /// - Returns: PNG data representation of the image
    /// - Throws: CGImageConversionError if the conversion process fails
    func pngData() throws -> Data {
        let data: NSMutableData = NSMutableData()

        guard let destination: CGImageDestination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw CGImageConversionError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, self, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CGImageConversionError.imageConversionFailed
        }

        return data as Data
    }
}

internal enum CGImageConversionError: Error {
    case destinationCreationFailed
    case imageConversionFailed
}
