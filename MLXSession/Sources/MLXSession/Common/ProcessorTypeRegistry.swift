import Foundation
import Tokenizers

internal actor ProcessorTypeRegistry {

    internal init() {
        self.creators = [:]
    }

    internal init(creators: [String: (Data, any Tokenizer) throws -> any UserInputProcessor]) {
        self.creators = creators
    }

    private var creators: [String: (Data, any Tokenizer) throws -> any UserInputProcessor]

    internal func registerProcessorType(
        _ type: String,
        creator: @escaping (Data, any Tokenizer) throws -> any UserInputProcessor
    ) {
        creators[type] = creator
    }

    internal func createModel(
        configuration: Data,
        processorType: String,
        tokenizer: any Tokenizer
    ) throws -> sending any UserInputProcessor {
        guard let creator = creators[processorType] else {
            throw ModelFactoryError.unsupportedProcessorType(processorType)
        }
        return try creator(configuration, tokenizer)
    }
}
