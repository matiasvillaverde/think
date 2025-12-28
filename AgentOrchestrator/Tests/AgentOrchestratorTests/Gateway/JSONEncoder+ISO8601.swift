import Foundation

extension JSONEncoder {
    internal static var iso8601: JSONEncoder {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
