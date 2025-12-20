import Foundation

extension FileProcessor {
    public enum FileProcessorError: Error, LocalizedError, Equatable {
        case couldNotReadFile(String)
        case fileISEmpty
        case unsupportedFileType
        case invalidJSONFormat
        case pdfTextExtractionFailed
        case unsupportedOperation(String)

        public var errorDescription: String? {
            switch self {
            case .couldNotReadFile(let details):
                return "Could not read file: \(details)"

            case .fileISEmpty:
                return "The file is empty"

            case .unsupportedFileType:
                return "This file type is not supported"

            case .invalidJSONFormat:
                return "The JSON file is not properly formatted"

            case .pdfTextExtractionFailed:
                return "Failed to extract text from PDF"

            case .unsupportedOperation(let details):
                return "Unsupported operation: \(details)"
            }
        }
    }
}
