import Foundation
import CoreGraphics

/// Protocol defining the interface for image generation view models
///
/// This protocol establishes the contract for view models that handle
/// image generation functionality within the application. It provides
/// methods for generating images, managing generation state, and
/// responding to model lifecycle events.
public protocol ViewModelImageGenerating: Actor {
    /// Generates an image based on the provided prompt and model
    ///
    /// This method initiates the image generation process using the specified
    /// model and prompt. The generation happens asynchronously and updates
    /// are communicated through the database.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image
    ///   - model: The diffusion model to use for generation
    ///   - chatId: The ID of the chat where the image is being generated
    ///   - messageId: The ID of the message to associate with the generated image
    ///   - contextPrompt: Additional context to enhance the prompt
    /// - Throws: An error if image generation fails
    func generateImage(
        prompt: String,
        model: SendableModel,
        chatId: UUID,
        messageId: UUID,
        contextPrompt: String
    ) async throws

    /// Stops any ongoing image generation process
    ///
    /// This method cancels the current image generation if one is in progress.
    /// It ensures proper cleanup of resources and updates the generation state.
    ///
    /// - Throws: An error if stopping the generation fails
    func stop() async throws

    /// Called when a model is unloaded from memory
    ///
    /// This method allows the view model to update its internal state when
    /// a model is unloaded by another component.
    ///
    /// - Parameter id: The UUID of the unloaded model
    func modelWasUnloaded(id: UUID) async
}
