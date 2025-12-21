@preconcurrency import AVFoundation
import CoreImage
import Foundation
import MLX
import Tokenizers

internal typealias Message = [String: any Sendable]

internal struct UserInput {

    internal enum Prompt: CustomStringConvertible {
        case text(String)
        case messages([Message])
        case chat([Chat.Message])

        internal var description: String {
            switch self {
            case .text(let text):
                return text
            case .messages(let messages):
                return messages.map { $0.description }.joined(separator: "\n")
            case .chat(let messages):
                return messages.map(\.content).joined(separator: "\n")
            }
        }
    }

    internal struct VideoFrame {
        internal let frame: CIImage
        internal let timeStamp: CMTime

        internal init(frame: CIImage, timeStamp: CMTime) {
            self.frame = frame
            self.timeStamp = timeStamp
        }
    }

    internal enum Video {
        case avAsset(AVAsset)
        case url(URL)
        case frames([VideoFrame])

        @available(
            *, deprecated,
            message: "Use MediaProcessing.asProcessedSequence() with the Video directly"
        )
        internal func asAVAsset() -> AVAsset {
            switch self {
            case .avAsset(let asset):
                return asset
            case .url(let url):
                return AVAsset(url: url)
            case .frames:
                fatalError("calling asAVAsset() on Video with frames is unsupported")
            }
        }
    }

    internal enum Image {
        case ciImage(CIImage)
        case url(URL)
        case array(MLXArray)

        internal func asCIImage() throws -> CIImage {
            switch self {
            case .ciImage(let image):
                return image
            case .url(let url):
                if let image = CIImage(contentsOf: url) {
                    return image
                }
                throw UserInputError.unableToLoad(url)
            case .array(let array):
                guard array.ndim == 3 else {
                    throw UserInputError.arrayError("array must have 3 dimensions: \(array.ndim)")
                }

                var array = array
                if array.max().item(Float.self) <= 1.0 {
                    array = array * 255
                }

                switch array.dim(0) {
                case 3, 4:
                    array = array.transposed(1, 2, 0)
                default:
                    break
                }

                switch array.dim(-1) {
                case 3:
                    array = padded(array, widths: [0, 0, [0, 1]], value: MLXArray(255))
                case 4:
                    break
                default:
                    throw UserInputError.arrayError(
                        "channel dimension must be last and 3/4: \(array.shape)")
                }

                let arrayData = array.asData()
                let (height, width, _) = array.shape3
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
                return CIImage(
                    bitmapData: arrayData.data,
                    bytesPerRow: width * 4,
                    size: .init(width: width, height: height),
                    format: .RGBA8,
                    colorSpace: colorSpace
                )
            }
        }
    }

    internal struct Processing: Sendable {
        internal var resize: CGSize?

        internal init(resize: CGSize? = nil) {
            self.resize = resize
        }
    }

    internal var prompt: Prompt {
        didSet {
            switch prompt {
            case .text, .messages:
                break
            case .chat(let messages):
                self.images = messages.reduce(into: []) { result, message in
                    result.append(contentsOf: message.images)
                }
                self.videos = messages.reduce(into: []) { result, message in
                    result.append(contentsOf: message.videos)
                }
            }
        }
    }

    internal var images = [Image]()
    internal var videos = [Video]()
    internal var additionalContext: [String: any Sendable]?
    internal var processing: Processing = .init()

    internal init(
        prompt: String,
        images: [Image] = [Image](),
        videos: [Video] = [Video](),
        additionalContext: [String: any Sendable]? = nil
    ) {
        self.prompt = .chat([
            .user(prompt, images: images, videos: videos)
        ])
        self.images = images
        self.videos = videos
        self.additionalContext = additionalContext
    }

    internal init(
        messages: [Message],
        images: [Image] = [Image](),
        videos: [Video] = [Video](),
        additionalContext: [String: any Sendable]? = nil
    ) {
        self.prompt = .messages(messages)
        self.images = images
        self.videos = videos
        self.additionalContext = additionalContext
    }

    internal init(
        chat: [Chat.Message],
        additionalContext: [String: any Sendable]? = nil
    ) {
        self.prompt = .chat(chat)
        self.additionalContext = additionalContext
        self.images = chat.reduce(into: []) { result, message in
            result.append(contentsOf: message.images)
        }
        self.videos = chat.reduce(into: []) { result, message in
            result.append(contentsOf: message.videos)
        }
    }
}

internal protocol UserInputProcessor: Sendable {
    func prepare(input: UserInput) async throws -> LMInput
}

internal enum UserInputError: LocalizedError {
    case notImplemented
    case unableToLoad(URL)
    case arrayError(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "This functionality is not implemented."
        case .unableToLoad(let url):
            return "Unable to load image from URL: \(url.path)."
        case .arrayError(let message):
            return "Error processing image array: \(message)."
        }
    }
}

internal struct StandInUserInputProcessor: UserInputProcessor {
    internal init() {}

    internal func prepare(input: UserInput) throws -> LMInput {
        throw UserInputError.notImplemented
    }
}
