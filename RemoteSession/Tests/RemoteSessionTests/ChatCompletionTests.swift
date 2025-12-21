import Foundation
import Testing
@testable import RemoteSession

@Suite("Chat Completion Tests")
struct ChatCompletionTests {
    @Test("Encode request with all parameters")
    func encodeRequestWithAllParameters() throws {
        let request = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatMessage(role: .system, content: "You are a helpful assistant"),
                ChatMessage(role: .user, content: "Hello")
            ],
            stream: true,
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1024,
            stop: ["User:"],
            frequencyPenalty: 0.5,
            presencePenalty: 0.5
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "gpt-4o-mini")
        #expect(json?["stream"] as? Bool == true)
        #expect(json?["temperature"] as? Double == 0.7)
        #expect(json?["top_p"] as? Double == 0.9)
        #expect(json?["max_tokens"] as? Int == 1024)
        #expect((json?["stop"] as? [String])?.first == "User:")
        #expect(json?["frequency_penalty"] as? Double == 0.5)
        #expect(json?["presence_penalty"] as? Double == 0.5)
    }

    @Test("Encode request with minimal parameters")
    func encodeRequestWithMinimalParameters() throws {
        let request = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [ChatMessage(role: .user, content: "Hello")]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "gpt-4o-mini")
        #expect(json?["stream"] as? Bool == true)
        #expect(json?["temperature"] == nil)
        #expect(json?["max_tokens"] == nil)
    }

    @Test("Decode streaming chunk response")
    func decodeStreamingChunkResponse() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1677652288,
            "model": "gpt-4o-mini",
            "choices": [{
                "index": 0,
                "delta": {
                    "content": "Hello"
                },
                "finish_reason": null
            }]
        }
        """

        let data = Data(json.utf8)
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)

        #expect(chunk.id == "chatcmpl-123")
        #expect(chunk.model == "gpt-4o-mini")
        #expect(chunk.choices.first?.delta.content == "Hello")
        #expect(chunk.choices.first?.finishReason == nil)
    }

    @Test("Decode finish_reason in final chunk")
    func decodeFinishReasonInFinalChunk() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1677652288,
            "model": "gpt-4o-mini",
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }]
        }
        """

        let data = Data(json.utf8)
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)

        #expect(chunk.choices.first?.finishReason == "stop")
    }

    @Test("Handle null content in delta")
    func handleNullContentInDelta() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1677652288,
            "model": "gpt-4o-mini",
            "choices": [{
                "index": 0,
                "delta": {
                    "role": "assistant"
                },
                "finish_reason": null
            }]
        }
        """

        let data = Data(json.utf8)
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)

        #expect(chunk.choices.first?.delta.role == "assistant")
        #expect(chunk.choices.first?.delta.content == nil)
    }

    @Test("Decode usage in final chunk")
    func decodeUsageInFinalChunk() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1677652288,
            "model": "gpt-4o-mini",
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }
        """

        let data = Data(json.utf8)
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)

        #expect(chunk.usage?.promptTokens == 10)
        #expect(chunk.usage?.completionTokens == 20)
        #expect(chunk.usage?.totalTokens == 30)
    }
}
