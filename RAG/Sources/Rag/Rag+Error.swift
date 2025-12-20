import Foundation

extension Rag {
    public enum RagError: Error, LocalizedError, Equatable {
        case unsupportedFileType

        public var errorDescription: String? {
            switch self {
            case .unsupportedFileType:
                return "This file type is not supported"
            }
        }
    }
}
