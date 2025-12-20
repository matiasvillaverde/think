import Abstractions
import CoreGraphics
import Foundation
import Testing

/// Mock implementation of ImageGenerating for testing
public actor MockImageGenerating: ImageGenerating {
    /// Tracks all method calls
    public struct MethodCall: Equatable, Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date

        public init(method: String, parameters: [String: String] = [:]) {
            self.method = method
            self.parameters = parameters
            self.timestamp = Date()
        }

        public static func == (lhs: MethodCall, rhs: MethodCall) -> Bool {
            lhs.method == rhs.method && lhs.parameters == rhs.parameters
        }
    }

    /// Mock response for load method
    public struct MockLoadResponse: Sendable {
        public let progress: [ImageGenerationProgress]
        public let error: Error?
        public let delayBetweenProgress: TimeInterval

        public init(
            progress: [ImageGenerationProgress] = [],
            error: Error? = nil,
            delayBetweenProgress: TimeInterval = 0.01
        ) {
            self.progress = progress
            self.error = error
            self.delayBetweenProgress = delayBetweenProgress
        }

        /// Create a standard loading response
        public static func loading() -> MockLoadResponse {
            let progressItems: [ImageGenerationProgress] = [
                ImageGenerationProgress(
                    stage: .loadingTokenizer,
                    progressPercentage: 0.1
                ),
                ImageGenerationProgress(
                    stage: .loadingTextEncoder,
                    progressPercentage: 0.3
                ),
                ImageGenerationProgress(
                    stage: .loadingUnet,
                    progressPercentage: 0.5
                ),
                ImageGenerationProgress(
                    stage: .loadingVAEDecoder,
                    progressPercentage: 0.7
                ),
                ImageGenerationProgress(
                    stage: .compilingModels,
                    progressPercentage: 0.9
                ),
                ImageGenerationProgress(
                    stage: .completed,
                    progressPercentage: 1.0
                )
            ]
            return MockLoadResponse(progress: progressItems)
        }

        /// Create an error response
        public static func error(_ error: Error) -> MockLoadResponse {
            MockLoadResponse(progress: [], error: error)
        }
    }

    /// Mock response for generate method
    public struct MockGenerateResponse: Sendable {
        public let progress: [ImageGenerationProgress]
        public let error: Error?
        public let delayBetweenProgress: TimeInterval

        public init(
            progress: [ImageGenerationProgress] = [],
            error: Error? = nil,
            delayBetweenProgress: TimeInterval = 0.01
        ) {
            self.progress = progress
            self.error = error
            self.delayBetweenProgress = delayBetweenProgress
        }

        /// Create a standard generation response with mock image
        public static func generating(steps: Int = 10) -> MockGenerateResponse {
            var progressItems: [ImageGenerationProgress] = []

            // Initial stages
            progressItems.append(ImageGenerationProgress(
                stage: .tokenizingPrompt,
                progressPercentage: 0.05
            ))
            progressItems.append(ImageGenerationProgress(
                stage: .encodingText,
                progressPercentage: 0.1
            ))

            // Generation steps
            for step in 1...steps {
                let progress = Double(step) / Double(steps)
                progressItems.append(ImageGenerationProgress(
                    stage: .generating(step: step, totalSteps: steps),
                    currentImage: createMockImage(),
                    progressPercentage: 0.1 + (0.8 * progress)
                ))
            }

            // Final stages
            progressItems.append(ImageGenerationProgress(
                stage: .decodingLatents,
                progressPercentage: 0.95
            ))
            progressItems.append(ImageGenerationProgress(
                stage: .completed,
                currentImage: createMockImage(),
                progressPercentage: 1.0,
                imageMetrics: ImageMetrics(
                    timing: ImageTimingMetrics(
                        totalTime: Duration.seconds(6.8),
                        modelLoadTime: Duration.seconds(2.0),
                        promptEncodingTime: Duration.seconds(0.3),
                        denoisingStepTimes: (0..<10).map { _ in Duration.milliseconds(450) },
                        vaeDecodingTime: nil
                    ),
                    usage: ImageUsageMetrics(
                        activeMemory: 1024 * 1024 * 400,
                        peakMemory: 1024 * 1024 * 512,
                        modelParameters: 1_000_000_000,
                        promptTokens: 77,
                        negativePromptTokens: nil,
                        gpuMemory: nil,
                        usedGPU: false
                    ),
                    generation: ImageGenerationMetrics(
                        width: 512,
                        height: 512,
                        steps: 10,
                        guidanceScale: 7.5,
                        scheduler: "DPMSolverMultistep",
                        modelName: "test-model",
                        seed: 42,
                        batchSize: 1
                    )
                )
            ))

            return MockGenerateResponse(progress: progressItems)
        }

        /// Create an error response
        public static func error(_ error: Error) -> MockGenerateResponse {
            MockGenerateResponse(progress: [], error: error)
        }

        /// Helper to create a mock CGImage
        private static func createMockImage() -> CGImage? {
            let width = 512
            let height = 512
            let bitsPerComponent = 8
            let bytesPerRow = width * 4

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                return nil
            }

            var data = [UInt8](repeating: 128, count: height * bytesPerRow)

            // Create a simple gradient pattern for visual testing
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * bytesPerRow) + (x * 4)
                    data[offset] = UInt8((x * 255) / width)     // Red
                    data[offset + 1] = UInt8((y * 255) / height) // Green
                    data[offset + 2] = 128                       // Blue
                    data[offset + 3] = 255                       // Alpha
                }
            }

            guard let provider = CGDataProvider(data: Data(bytes: data, count: data.count) as CFData) else {
                return nil
            }

            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }

    // MARK: - Properties

    private var methodCalls: [MethodCall] = []
    private var loadResponse: MockLoadResponse?
    private var generateResponse: MockGenerateResponse?
    private var shouldThrowOnStop: Error?
    private var shouldThrowOnUnload: Error?
    private var currentTasks: [UUID: Task<Void, Never>] = [:]
    private var isLoaded: Set<UUID> = []

    // MARK: - Configuration

    public init() {
        // Initialize with default configuration
    }

    /// Configure the mock to return specific load response
    public func configureLoadResponse(_ response: MockLoadResponse) {
        self.loadResponse = response
    }

    /// Configure the mock to return specific generate response
    public func configureGenerateResponse(_ response: MockGenerateResponse) {
        self.generateResponse = response
    }

    /// Configure the mock to throw an error on stop
    public func configureShouldThrowOnStop(_ error: Error?) {
        self.shouldThrowOnStop = error
    }

    /// Configure the mock to throw an error on unload
    public func configureShouldThrowOnUnload(_ error: Error?) {
        self.shouldThrowOnUnload = error
    }

    /// Get all recorded method calls
    public func getMethodCalls() -> [MethodCall] {
        methodCalls
    }

    /// Clear all recorded method calls
    public func clearMethodCalls() {
        methodCalls.removeAll()
    }

    /// Check if a model is loaded
    public func isModelLoaded(_ modelId: UUID) -> Bool {
        isLoaded.contains(modelId)
    }

    // MARK: - ImageGenerating Protocol

    public func load(model: SendableModel) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        methodCalls.append(MethodCall(
            method: "load",
            parameters: ["modelId": model.id.uuidString]
        ))

        let response = loadResponse ?? MockLoadResponse.loading()

        return AsyncThrowingStream { continuation in
            let task = Task {
                if let error = response.error {
                    continuation.finish(throwing: error)
                    return
                }

                for progress in response.progress {
                    continuation.yield(progress)
                    try? await Task.sleep(nanoseconds: UInt64(response.delayBetweenProgress * 1_000_000_000))
                }

                isLoaded.insert(model.id)
                continuation.finish()
            }
            currentTasks[model.id] = task
        }
    }

    public func stop(model: UUID) throws {
        methodCalls.append(MethodCall(
            method: "stop",
            parameters: ["modelId": model.uuidString]
        ))

        if let error = shouldThrowOnStop {
            throw error
        }

        if let task = currentTasks[model] {
            task.cancel()
            currentTasks[model] = nil
        }
    }

    public func generate(
        model: SendableModel,
        config: ImageConfiguration
    ) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        methodCalls.append(MethodCall(
            method: "generate",
            parameters: [
                "modelId": model.id.uuidString,
                "prompt": config.prompt
            ]
        ))

        let response = generateResponse ?? MockGenerateResponse.generating()

        return AsyncThrowingStream { continuation in
            let task = Task {
                if let error = response.error {
                    continuation.finish(throwing: error)
                    return
                }

                for progress in response.progress {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    continuation.yield(progress)
                    try? await Task.sleep(nanoseconds: UInt64(response.delayBetweenProgress * 1_000_000_000))
                }

                continuation.finish()
            }
            currentTasks[model.id] = task
        }
    }

    public func unload(model: UUID) throws {
        methodCalls.append(MethodCall(
            method: "unload",
            parameters: ["modelId": model.uuidString]
        ))

        if let error = shouldThrowOnUnload {
            throw error
        }

        isLoaded.remove(model)
        currentTasks[model] = nil
    }
}
