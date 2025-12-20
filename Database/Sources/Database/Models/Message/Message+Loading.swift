import Foundation

// MARK: - Loading state

extension Message {
    public enum Loading: String, Decodable {
        case languageModel
        case imageModel
        case none

        public var isLoading: Bool {
            switch self {
            case .languageModel, .imageModel:
                return true
            default:
                return false
            }
        }
    }
}
