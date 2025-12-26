import Abstractions
import Foundation
import Testing
@testable import RemoteSession

@Suite("Remote Models Decoder Tests")
struct RemoteModelsDecoderTests {
    @Test("Decodes OpenRouter models")
    func decodesOpenRouterModels() throws {
        let json = """
        {
          "data": [
            {
              "id": "openai/gpt-4o-mini",
              "name": "GPT-4o Mini",
              "description": "Test model",
              "context_length": 128000,
              "pricing": { "prompt": "0", "completion": "0" },
              "architecture": { "input_modalities": ["text"], "output_modalities": ["text"] }
            }
          ]
        }
        """
        let models = try RemoteModelsDecoder.decodeOpenRouter(Data(json.utf8))
        #expect(models.count == 1)
        #expect(models.first?.location == "openrouter:openai/gpt-4o-mini")
        #expect(models.first?.pricing == .free)
    }

    @Test("Decodes OpenAI models")
    func decodesOpenAIModels() throws {
        let json = """
        { "data": [ { "id": "gpt-4o-mini" } ] }
        """
        let models = try RemoteModelsDecoder.decodeOpenAI(Data(json.utf8))
        #expect(models.count == 1)
        #expect(models.first?.location == "openai:gpt-4o-mini")
    }

    @Test("Decodes Anthropic models")
    func decodesAnthropicModels() throws {
        let json = """
        { "data": [ { "id": "claude-3-haiku-20240307", "display_name": "Claude 3 Haiku" } ] }
        """
        let models = try RemoteModelsDecoder.decodeAnthropic(Data(json.utf8))
        #expect(models.count == 1)
        #expect(models.first?.location == "anthropic:claude-3-haiku-20240307")
        #expect(models.first?.displayName == "Claude 3 Haiku")
    }

    @Test("Decodes Google models using baseModelId")
    func decodesGoogleModels() throws {
        let json = """
        {
          "models": [
            {
              "name": "models/gemini-1.5-flash-001",
              "baseModelId": "gemini-1.5-flash",
              "displayName": "Gemini 1.5 Flash",
              "description": "Fast model",
              "inputTokenLimit": 32768,
              "supportedGenerationMethods": ["generateContent"]
            }
          ]
        }
        """
        let models = try RemoteModelsDecoder.decodeGoogle(Data(json.utf8))
        #expect(models.count == 1)
        #expect(models.first?.modelId == "gemini-1.5-flash")
        #expect(models.first?.location == "google:gemini-1.5-flash")
    }
}
