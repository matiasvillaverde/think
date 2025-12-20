//
//  LLMSession.swift
//
//  A unified API for streaming text generation from Large Language Models.
//
//  This API provides a minimal, focused abstraction over various LLM providers,
//  recognizing that all LLMs fundamentally do one thing: generate text tokens
//  in response to a prompt. Features like tool calling, structured output, and
//  chat formatting are simply conventions built on top of text generation.
//

import Foundation

/// The fundamental protocol that all LLM providers must implement.
///
/// This protocol defines a single, unified interface for streaming text generation
/// from any Large Language Model, whether it's a local model (llama.cpp), a cloud
/// API (OpenAI, Anthropic), or an aggregator service (OpenRouter).
///
/// The protocol is designed as an Actor to ensure thread-safe access to the
/// underlying provider resources, which may include network connections, model
/// state, or hardware accelerators.
public protocol LLMSession: Actor {
    /// Stream text generation based on the provided configuration.
    ///
    /// This method initiates text generation and returns an asynchronous stream
    /// of chunks. Each chunk contains generated text and optional metrics about
    /// the generation process.
    ///
    /// - Parameter config: The complete configuration for text generation,
    ///   including the prompt, model selection, and generation parameters.
    /// - Returns: An asynchronous stream that yields text chunks as they are
    ///   generated, along with optional performance metrics.
    /// - Throws: Provider-specific errors related to authentication, rate limits,
    ///   model availability, or other operational issues.
    ///
    /// - Note: The stream automatically handles backpressure and cancellation.
    ///   If the consumer stops reading from the stream, the provider should
    ///   gracefully stop generation to avoid wasting resources.
    func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error>

    nonisolated func stop()

    /// Preloads a model into memory for faster inference.
    ///
    /// This method allows providers to load models proactively, reducing
    /// the latency of the first generation request. This is particularly
    /// useful for large models that take significant time to initialize.
    ///
    /// - Parameter configuration: The configuration identifying the model to preload
    /// - Throws: `LLMError` if the model cannot be loaded (e.g., insufficient memory,
    ///   model not found, or invalid configuration)
    ///
    /// - Note: Providers should implement this as a no-op if they don't support
    ///   preloading or if the model is already loaded. The method should be
    ///   idempotent - calling it multiple times with the same configuration
    ///   should not cause errors.
    func preload(configuration: ProviderConfiguration) -> AsyncThrowingStream<Progress, Error>

    /// Unloads a model from memory to free resources.
    ///
    /// This method allows explicit resource management, enabling applications
    /// to free memory when a model is no longer needed. This is crucial for
    /// memory-constrained environments or when switching between models.
    ///
    /// - Note: This method should be safe to call even if the model is not loaded.
    ///   Providers should handle this gracefully without throwing errors.
    ///   After unloading, subsequent generation requests will need to reload
    ///   the model, which may introduce latency.
    func unload() async
}
