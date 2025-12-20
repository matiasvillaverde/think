import Foundation

/// Configuration for AgentOrchestrator module
internal struct AgentOrchestratorConfiguration: Sendable {
    /// Logging configuration
    internal struct Logging: Sendable {
        /// Subsystem identifier for logging
        internal let subsystem: String

        /// Debug token chunk size limit for logging
        internal let debugTokenChunkSizeLimit: Int

        /// Debug text preview length
        internal let debugTextPreviewLength: Int

        internal init(
            subsystem: String = "AgentOrchestrator",
            debugTokenChunkSizeLimit: Int = 50,
            debugTextPreviewLength: Int = 100
        ) {
            self.subsystem = subsystem
            self.debugTokenChunkSizeLimit = debugTokenChunkSizeLimit
            self.debugTextPreviewLength = debugTextPreviewLength
        }
    }

    /// Placeholder image generation configuration
    internal struct PlaceholderImage: Sendable {
        /// Default image size in pixels
        internal let defaultSize: Int

        /// Gradient start color (red component)
        internal let gradientStartRed: Float

        /// Gradient start color (green component)
        internal let gradientStartGreen: Float

        /// Gradient start color (blue component)
        internal let gradientStartBlue: Float

        /// Gradient end color (blue component)
        internal let gradientEndBlue: Float

        internal init(
            defaultSize: Int = 512,
            gradientStartRed: Float = 128.0,
            gradientStartGreen: Float = 64.0,
            gradientStartBlue: Float = 128.0,
            gradientEndBlue: Float = 127.0
        ) {
            self.defaultSize = defaultSize
            self.gradientStartRed = gradientStartRed
            self.gradientStartGreen = gradientStartGreen
            self.gradientStartBlue = gradientStartBlue
            self.gradientEndBlue = gradientEndBlue
        }
    }

    /// Generation chain configuration
    internal struct Generation: Sendable {
        /// Maximum iterations for generation chain
        internal let defaultMaxIterations: Int

        internal init(defaultMaxIterations: Int = 10) {
            self.defaultMaxIterations = defaultMaxIterations
        }
    }

    /// Streaming configuration
    internal struct Streaming: Sendable {
        /// Throttle interval for real-time updates during streaming (in milliseconds)
        internal let throttleIntervalMilliseconds: Int

        internal init(throttleIntervalMilliseconds: Int = 150) {
            self.throttleIntervalMilliseconds = throttleIntervalMilliseconds
        }
    }

    /// Memory batch size configuration
    internal struct Memory: Sendable {
        /// Small batch size for low memory situations
        internal let smallBatchSize: Int

        /// Medium batch size for normal memory situations
        internal let mediumBatchSize: Int

        /// Large batch size for high memory situations
        internal let largeBatchSize: Int

        internal init(
            smallBatchSize: Int = 512,
            mediumBatchSize: Int = 1_024,
            largeBatchSize: Int = 2_048
        ) {
            self.smallBatchSize = smallBatchSize
            self.mediumBatchSize = mediumBatchSize
            self.largeBatchSize = largeBatchSize
        }
    }

    /// Logging configuration
    internal let logging: Logging

    /// Placeholder image configuration
    internal let placeholderImage: PlaceholderImage

    /// Generation configuration
    internal let generation: Generation

    /// Streaming configuration
    internal let streaming: Streaming

    /// Memory configuration
    internal let memory: Memory

    /// Shared configuration instance
    internal static let shared: Self = Self()

    internal init(
        logging: Logging = Logging(),
        placeholderImage: PlaceholderImage = PlaceholderImage(),
        generation: Generation = Generation(),
        streaming: Streaming = Streaming(),
        memory: Memory = Memory()
    ) {
        self.logging = logging
        self.placeholderImage = placeholderImage
        self.generation = generation
        self.streaming = streaming
        self.memory = memory
    }
}
