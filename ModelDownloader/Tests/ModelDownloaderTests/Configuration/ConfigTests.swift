import Foundation
@testable import ModelDownloader
import Testing

internal enum TestError: Error {
    case invalidData
}

@Test("Config should support dynamic member lookup")
internal func testDynamicMemberLookup() throws {
    let dictionary: [String: Any] = [
        "model_type": "gpt2",
        "vocab_size": 50_257,
        "hidden_size": 768
    ]

    let config: Config = Config(dictionary)

    #expect(config.modelType?.stringValue == "gpt2")
    #expect(config.vocabSize?.intValue == 50_257)
    #expect(config.hiddenSize?.intValue == 768)
}

@Test("Config should convert camelCase to snake_case")
internal func testCamelCaseConversion() throws {
    let config: Config = Config([:])

    #expect(config.uncamelCase("modelType") == "model_type")
    #expect(config.uncamelCase("vocabSize") == "vocab_size")
    #expect(config.uncamelCase("hiddenSize") == "hidden_size")
    #expect(config.uncamelCase("simpleword") == "simpleword")
}

@Test("Config should convert snake_case to camelCase")
internal func testSnakeCaseConversion() throws {
    let config: Config = Config([:])

    #expect(config.camelCase("model_type") == "modelType")
    #expect(config.camelCase("vocab_size") == "vocabSize")
    #expect(config.camelCase("hidden_size") == "hiddenSize")
    #expect(config.camelCase("simpleword") == "simpleword")
}

@Test("Config should handle nested configurations")
internal func testNestedConfiguration() throws {
    let dictionary: [String: Any] = [
        "tokenizer": [
            "class": "GPT2Tokenizer",
            "vocab_size": 50_257
        ] as [String: Any]
    ]

    let config: Config = Config(dictionary)
    let tokenizerConfig: Config? = config.tokenizer

    #expect(tokenizerConfig != nil)
    #expect(tokenizerConfig?.class?.stringValue == "GPT2Tokenizer")
    #expect(tokenizerConfig?.vocabSize?.intValue == 50_257)
}

@Test("Config should handle array values")
internal func testArrayValues() throws {
    let dictionary: [String: Any] = [
        "architectures": [
            ["name": "GPT2LMHeadModel"] as [String: Any],
            ["name": "GPT2Model"] as [String: Any]
        ]
    ]

    let config: Config = Config(dictionary)
    let architectures: [Config] = config.architectures?.arrayValue ?? []

    #expect(!architectures.isEmpty)
    #expect(architectures.count == 2)
    #expect(architectures[0].name?.stringValue == "GPT2LMHeadModel")
    #expect(architectures[1].name?.stringValue == "GPT2Model")
}

@Test("Config should handle wrapped values correctly")
internal func testConfigValueTypes() throws {
    // Test a Config that wraps a single value (like what dynamic member lookup creates)
    let stringConfig: Config = Config(["value": "test"])
    let intConfig: Config = Config(["value": 42])
    let boolConfig: Config = Config(["value": true])
    let doubleConfig: Config = Config(["value": 3.14])

    #expect(stringConfig.stringValue == "test")
    #expect(intConfig.intValue == 42)
    #expect(boolConfig.boolValue)
    #expect(doubleConfig.value as? Double == 3.14)
}

@Test("Config should return nil for non-existent keys")
internal func testNonExistentKeys() throws {
    let config: Config = Config([:])

    #expect(config.nonExistentKey == nil)
    #expect(config.anotherMissingKey?.stringValue == nil)
}

@Test("Config should handle token values as tuples")
internal func testTokenValues() throws {
    let dictionary: [String: Any] = [
        "special_token": (50_256 as UInt, "<|endoftext|>" as String)
    ]

    let config: Config = Config(dictionary)
    let tokenValue: (UInt, String)? = config.specialToken?.tokenValue

    #expect(tokenValue != nil)
    #expect(tokenValue?.0 == 50_256)
    #expect(tokenValue?.1 == "<|endoftext|>")
}

@Test("Config should be created from JSON data")
internal func testConfigFromJSON() throws {
    let jsonString: String = """
    {
        "model_type": "gpt2",
        "vocab_size": 50257,
        "architectures": ["GPT2LMHeadModel"],
        "bos_token_id": 50256,
        "eos_token_id": 50256
    }
    """

    guard let data: Data = jsonString.data(using: .utf8) else {
        throw TestError.invalidData
    }
    let json: Any = try JSONSerialization.jsonObject(with: data)
    guard let jsonDict: [String: Any] = json as? [String: Any] else { throw TestError.invalidData }
    let config: Config = Config(jsonDict)

    #expect(config.modelType?.stringValue == "gpt2")
    #expect(config.vocabSize?.intValue == 50_257)
    #expect(config.bosTokenId?.intValue == 50_256)
    #expect(config.eosTokenId?.intValue == 50_256)
}
