import Foundation

internal enum VLMError: LocalizedError, Equatable {
    case imageRequired
    case maskRequired
    case singleImageAllowed
    case singleVideoAllowed
    case singleMediaTypeAllowed
    case imageProcessingFailure(String)
    case processing(String)
    case noVideoTrackFound
    case videoNotDecodable

    var errorDescription: String? {
        switch self {
        case .imageRequired:
            return "An image is required for this operation."
        case .maskRequired:
            return "An image mask is required for this operation."
        case .singleImageAllowed:
            return "Only a single image is allowed for this operation."
        case .singleVideoAllowed:
            return "Only a single video is allowed for this operation."
        case .singleMediaTypeAllowed:
            return "Only a single media type (image or video) is allowed for this operation."
        case .imageProcessingFailure(let details):
            return "Failed to process the image: \(details)"
        case .processing(let details):
            return "Processing error: \(details)"
        case .noVideoTrackFound:
            return "Video file has no video tracks."
        case .videoNotDecodable:
            return "Video file not decodable."
        }
    }
}
