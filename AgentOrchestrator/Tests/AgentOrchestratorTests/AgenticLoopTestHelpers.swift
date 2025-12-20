import AbstractionsTestUtilities
import Foundation

internal enum AgenticLoopTestHelpers {
    private static let streamDelay: TimeInterval = 0.001

    internal static func createToolCallResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "I'll help you calculate that. Let me use the calculator tool.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"add\", \"first\": 15, \"second\": 27}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createMultipleToolCallResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "I'll help you with these calculations.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"multiply\", \"first\": 12, \"second\": 8}" +
            "<|recipient|>calculator<|call|>",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"add\", \"first\": 96, \"second\": 54}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createDivisionByZeroResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "Let me calculate that division.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"divide\", \"first\": 10, \"second\": 0}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createAreaCalculationResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "<|channel|>thinking<|message|>" +
            "User wants to know the area of a rectangle." +
            "<|end|>",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"multiply\", \"first\": 15.5, \"second\": 8.2}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createFirstChainedResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "I'll solve this step by step.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"add\", \"first\": 10, \"second\": 20}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createSecondChainedResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "Now I'll multiply the result by 3.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"multiply\", \"first\": 30, \"second\": 3}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createFinalResponse(_ message: String) -> MockLLMSession.MockStreamResponse {
        .text([
            "<|channel|>final<|message|>" +
            message +
            "<|end|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createErrorHandlingResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "<|channel|>final<|message|>" +
            "I apologize, but I cannot divide by zero. " +
            "This operation is mathematically undefined." +
            "<|end|>"
        ], delayBetweenChunks: streamDelay)
    }

    internal static func createAreaResultResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "<|channel|>final<|message|>" +
            "The area of a rectangle with dimensions 15.5m × 8.2m " +
            "is 127.1 square meters." +
            "<|end|>"
        ], delayBetweenChunks: streamDelay)
    }
}
