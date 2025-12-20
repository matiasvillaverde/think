// swiftlint:disable force_unwrapping force_try
import Foundation
import MLX
import MLXNN

// Utility class for loading voices
internal class VoiceLoader {
    private init() {
        // Static utility class
    }

    static func loadVoice(_ voice: TTSVoice) -> MLXArray {
        let (file, ext): (String, String) = Constants.voiceFiles[voice]!
        let filePath: String = Bundle.module.path(forResource: file, ofType: ext)!
        return try! read3DArrayFromJson(file: filePath, shape: [510, 1, 256])!
    }

    private static func read3DArrayFromJson(file: String, shape: [Int]) throws -> MLXArray? {
        guard shape.count == 3 else {
            return nil
        }

        let data: Data = try Data(contentsOf: URL(fileURLWithPath: file))
        let jsonObject: Any = try JSONSerialization.jsonObject(with: data, options: [])

        var flatArray: [Float] = Array(repeating: Float(0.0), count: shape[0] * shape[1] * shape[2])
        var flatIndex: Int = 0

        if let nestedArray = jsonObject as? [[[Any]]] {
            guard nestedArray.count == shape[0] else {
                return nil
            }
            for outerIndex in 0 ..< nestedArray.count {
                guard nestedArray[outerIndex].count == shape[1] else {
                    return nil
                }
                for middleIndex in 0 ..< nestedArray[outerIndex].count {
                    guard nestedArray[outerIndex][middleIndex].count == shape[2] else {
                        return nil
                    }
                    for innerIndex in 0 ..< nestedArray[outerIndex][middleIndex].count {
                        if let numberValue = nestedArray[outerIndex][middleIndex][innerIndex] as? Double {
                            flatArray[flatIndex] = Float(numberValue)
                            flatIndex += 1
                        } else {
                            fatalError("Cannot load value \(outerIndex), \(middleIndex), \(innerIndex) as double")
                        }
                    }
                }
            }
        } else {
            return nil
        }

        guard flatIndex == shape[0] * shape[1] * shape[2] else {
            fatalError("Mismatch in array size: \(flatIndex) vs \(shape[0] * shape[1] * shape[2])")
        }

        return MLXArray(flatArray).reshaped(shape)
    }

    private enum Constants {
        nonisolated(unsafe) static let voiceFiles: [TTSVoice: (String, String)] = [
            .afHeart: ("af_heart", "json"),
            .bmGeorge: ("bm_george", "json"),
            .zfXiaoni: ("zf_xiaoni", "json")
        ]
    }

    deinit {
        // No cleanup needed - static utility class
    }
}
// swiftlint:enable force_unwrapping force_try
