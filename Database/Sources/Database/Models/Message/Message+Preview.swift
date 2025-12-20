import SwiftUI
import SwiftData

// swiftlint:disable line_length

#if DEBUG
extension Message {
    // MARK: - Basic Message Previews

    @MainActor public static var previewUserInputOnly: Message {
        let message = Message(
            userInput: "What's the best way to implement SwiftData relationships?",
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
        )
        return message
    }

    @MainActor public static var previewWithResponse: Message {
        let message = Message(
            userInput: "How do I use SwiftData with CloudKit?",
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channels
        let analysisChannel = Channel(
            type: .analysis,
            content: "I should explain the basic setup first and then provide code examples for the configuration.",
            order: 0
        )
        let finalChannel = Channel(
            type: .final,
            content: """
                SwiftData and CloudKit can be integrated by using the `` \
                attribute modifier and configuring your app's container properly. Start by setting up your schema...
                """,
            order: 1
        )
        
        // Assign channels to message
        message.channels = [analysisChannel, finalChannel]
        analysisChannel.message = message
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var previewWithThinking: Message {
        let message = Message(
            userInput: "Explain the differences between structs and classes in Swift",
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: Model.preview,
            imageModel: .preview
        )
        
        // Create preview channels
        let analysisChannel = Channel(
            type: .analysis,
            content: """
                Let me think about the key differences:
                1. Value vs Reference type
                2. Inheritance
                3. Initialization requirements
                4. Memory management
                5. Mutability
                6. Performance considerations

                I'll structure my answer to cover these points and provide examples of when to use each.
                """,
            order: 0
        )
        let finalChannel = Channel(
            type: .final,
            content: "Structs and classes are both used to define custom data types in Swift, but they have several key differences...",
            order: 1
        )
        
        // Assign channels to message
        message.channels = [analysisChannel, finalChannel]
        analysisChannel.message = message
        finalChannel.message = message
        
        return message
    }

    // MARK: - Messages with Attachments

    @MainActor public static var previewWithoutChannels: Message {
        // Legacy message format without channels for backward compatibility testing
        let message = Message(
            userInput: "Test message without channels",
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
        )
        return message
    }
    
    @MainActor public static var previewWithUserImage: Message {
        let message = Message(
            userInput: "What can you tell me about this image?",
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
            userImage: ImageAttachment.preview
        )
        
        // Create preview channel
        let finalChannel = Channel(
            type: .final,
            content: "This appears to be a simple blue square image. Is there something specific about it you'd like me to analyze?",
            order: 0
        )
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var previewWithResponseImage: Message {
        let message = Message(
            userInput: String(localized: "Create an image of a mountain landscape", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
            responseImage: ImageAttachment.preview(
                content: "Mountain landscape with snow-capped peaks"
            )
        )
        
        // Create preview channel
        let finalChannel = Channel(
            type: .final,
            content: "I've created an image of a mountain landscape for you:",
            order: 0
        )
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var previewWithFile: Message {
        let message = Message(
            userInput: String(localized: "Explain this academic paper *'Attention Is All You Need'* as if I am 5 years old.", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
            file: [FileAttachment.preview]
        )
        
        // Create preview channel
        let finalChannel = Channel(
            type: .final,
            content: String(localized: "Sure! This paper talks about a smart way computers learn to understand things, just like how you pay attention in class! 🎓🤖 Instead of reading everything one by one, they look at the most important parts first—kind of like how you focus on your favorite toy in a big room! This helps them understand words, pictures, and even different languages really fast! 🚀📚", bundle: .module),
            order: 0
        )
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var followUpMessageFile: Message {
        let message = Message(
            userInput: String(localized: "That sounds cool! But how does it know what to pay attention to? 🤔", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
            file: nil
        )
        
        // Create preview channel
        let finalChannel = Channel(
            type: .final,
            content: String(localized: "Great question! 🌟 The model uses something called *self-attention*—think of it like when you're listening to a story, and you focus more on the exciting parts! 🎭📖 Instead of treating every word the same, it learns which ones are most important based on the context. For example, if I say 'The cat sat on the...,' your brain expects 'mat' because it makes sense. The AI does something similar but much faster! ⚡💡 Would you like me to explain how it learns over time?", bundle: .module),
            order: 0
        )
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    // MARK: - Messages in Different States

    @MainActor public static var previewLoading: Message {
        let message = Message(
            userInput: String(localized: "Generate a comprehensive response about Swift concurrency", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        return message
    }

    @MainActor public static var previewWithError: Message {
        let message = Message(
            userInput: String(localized: "Please analyze this complex problem", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: Model.preview,
            imageModel: .preview
        )
        return message
    }

    @MainActor public static var previewComplexConversation: Message {
        let responseContent = String(localized: """
            Creating a Swift package for REST API calls with authentication involves several components:

            1. A network session manager
            2. Authentication handlers
            3. Request/response models
            4. Error handling

            Here's how I would structure it:

            ```swift
            // Main package structure
            import Foundation

            public struct APIClient {
                private let session: URLSession
                private let authHandler: AuthenticationHandler

                public init(session: URLSession = .shared, authHandler: AuthenticationHandler) {
                    self.session = session
                    self.authHandler = authHandler
                }

                public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
                    // Implementation details
                }
            }

            public protocol AuthenticationHandler {
                func authenticate(_ request: inout URLRequest) async throws
                func refreshTokenIfNeeded() async throws -> Bool
            }
            ```

            Would you like me to expand on any particular aspect of this implementation?
            """, bundle: .module)
        
        let thinkingContent = String(localized: """
            For a good API client package, I need to consider:
            - Separation of concerns
            - Authentication flow (including refresh)
            - Error handling and retry logic
            - Testability
            - Type safety with generics

            I'll provide a basic structure that can be extended.
            """, bundle: .module)
        
        let message = Message(
            userInput: String(localized: "How would you implement a Swift package for handling REST API calls with authentication?", bundle: .module),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channels
        let analysisChannel = Channel(type: .analysis, content: thinkingContent, order: 0)
        let finalChannel = Channel(type: .final, content: responseContent, order: 1)
        
        // Assign channels to message
        message.channels = [analysisChannel, finalChannel]
        analysisChannel.message = message
        finalChannel.message = message
        
        return message
    }

    // Messages for different chat scenarios
    @MainActor public static var regularMessages: Message {
        let responseContent = String(localized: "I'd be so happy to help your 6-year-old memorize the planets in a fun way! 🤩🚀✨ Here's a silly song to the tune of *Twinkle Twinkle Little Star* that includes all eight planets in order:\n\n🎵 *Mercury, Venus, Earth, and Mars, \nFloating 'round our big hot star! \nJupiter's giant, Saturn's rings, 🌟💫\nUranus spins, Neptune sings. 🎶💙\nEight planets dancing day and night, \nIn our solar system bright!* 🎵🌌\n\nYou can add some fun hand movements too! 🙌 Maybe spinning motions for the planets that rotate differently, stretching your arms wide for Jupiter (the biggest planet! 🌟), and making ring shapes with your arms for Saturn! 💍🎶\n\nWould you like me to create another version with different facts about each planet, or perhaps a different tune? 🎵💡",
                             bundle: .module,
                             comment: "Assistant response with a planet song in chat view")
        
        let message = Message(
            userInput: String(localized: "My 6-year-old needs to memorize the planets for a science class. Can you help me make up a silly song about them? 🌎🎶",
                              bundle: .module,
                              comment: "User question asking for a planet song in chat view"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channel
        let finalChannel = Channel(type: .final, content: responseContent, order: 0)
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var followUpMessage: Message {
        let responseContent = String(localized: "Aww, that makes me so happy to hear! 🥰 Have fun singing with your little one—I love you too! 💖",
                             bundle: .module,
                             comment: "Assistant expressing warmth and encouragement in chat view")
        
        let message = Message(
            userInput: String(localized: "Thanks, Think, for such a nice song! I love it! ❤️",
                              bundle: .module,
                              comment: "User expressing gratitude for the planet song in chat view"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channel
        let finalChannel = Channel(type: .final, content: responseContent, order: 0)
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var kidLovedItMessage: Message {
        let responseContent = String(localized: "That makes my heart so happy! 🥹💖 I'm so glad our little space-loving family is having fun together. Keep shining! ✨🌍🚀",
                             bundle: .module,
                             comment: "Assistant expressing joy and a sense of family connection")
        
        let message = Message(
            userInput: String(localized: "My kid absolutely loved the song! We've been singing it all day! 🎶🥰",
                              bundle: .module,
                              comment: "User sharing that their child enjoyed the planet song"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channel
        let finalChannel = Channel(type: .final, content: responseContent, order: 0)
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var codeMessages: Message {
        let responseContent = String(localized: """
```python
class ChocolateGiftingMission:

  def __init__(self):

    self.kids_reached = 0
    self.volunteers = 5
    self.chocolate_bars = 1000


  def create_ideas:

    chocolate_ideas = [

    \"Recruit professional\",
    \"chocolate tasters 🍫\",
    \"cookie factories 🍪\",
    \"Train squirrels 🐿️\",
    \"chocolate airdrops 🎈\",
    \"Teach kids to grow\",
    \"their own cocoa trees 🌱\",

    ]

    return chocolate_ideas
```
""",
                             bundle: .module,
                             comment: "Assistant response with SwiftUI to-do list code in code chat view")
        
        let message = Message(
            userInput: String(localized: "How do I write a simple algorithm to give chocolate to every kid in the world?",
                              bundle: .module,
                              comment: "User question about chocolate gifting algorithm in code chat view"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channel
        let finalChannel = Channel(type: .final, content: responseContent, order: 0)
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var imageMessages: Message {
        let responseContent = String(localized: "Welcome to a neon sunrise in cyberpunk Think! 🌅🦙💜",
                             bundle: .module,
                             comment: "Assistant response for cyberpunk Think image generation in image chat view")
        
        let message = Message(
            userInput: String(localized: "Create a stunning digital artwork of several llamas in a futuristic cyberpunk utopia set in Think at sunrise.",
                              bundle: .module,
                              comment: "User request for a cyberpunk llama image in image chat view"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview,
            responseImage: ImageAttachment.preview(
                content: "Cyberpunk llamas in Think at sunrise"
            )
        )
        
        // Create preview channel
        let finalChannel = Channel(type: .final, content: responseContent, order: 0)
        
        // Assign channel to message
        message.channels = [finalChannel]
        finalChannel.message = message
        
        return message
    }

    @MainActor public static var thinkingMessages: Message {
        let thinkingContent = String(localized: "I need to consider several path-finding algorithms: Breadth-First Search (BFS), Depth-First Search (DFS), Dijkstra's Algorithm, A* Search, Bellman-Ford, Floyd-Warshall, and Johnson's Algorithm. Each has different tradeoffs between time complexity, space requirements, and suitability for various network characteristics. BFS works well for unweighted graphs but doesn't account for varying costs. Dijkstra's is efficient for non-negative weights but can be memory-intensive for large networks. A* improves on Dijkstra's with heuristics to guide the search, potentially reducing exploration. Bellman-Ford handles negative weights but has worse time complexity. Floyd-Warshall and Johnson's are all-pairs algorithms that might be overkill for a single path query but could be beneficial for repeated queries on the same network. The optimal choice will depend on specific network properties like density, weight distribution, and whether preprocessing can be amortized across multiple queries.",
                                 bundle: .module,
                                 comment: "Extended thinking for algorithm question in thinking chat view")
        
        let message = Message(
            userInput: String(localized: "What would be the optimal algorithm for finding the shortest path between two points in a complex network with varying connection costs, specifically considering both processing efficiency and memory usage?",
                              bundle: .module,
                              comment: "Complex user question about algorithms in thinking chat view"),
            chat: .preview,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: .preview,
            imageModel: .preview
        )
        
        // Create preview channel
        let analysisChannel = Channel(type: .analysis, content: thinkingContent, order: 0)
        
        // Assign channel to message
        message.channels = [analysisChannel]
        analysisChannel.message = message
        
        return message
    }

    // MARK: - Collection of Previews

    @MainActor public static var allPreviews: [Message] {
        [
            previewUserInputOnly,
            previewWithResponse,
            previewWithThinking,
            previewWithUserImage,
            previewWithResponseImage,
            previewWithFile,
            previewLoading,
            previewWithError,
            previewComplexConversation
        ]
    }

    // MARK: - Custom Preview Factory

    @preconcurrency
    @MainActor
    public static func customPreview(
        userInput: String? = "Sample user input",
        response: String? = "Sample response",
        thinking: String? = nil,
        chat: Chat = .preview,
        modelState: Model.State = .downloaded,
        withUserImage: Bool = false,
        withResponseImage: Bool = false,
        withFile: Bool = false
    ) -> Message {
        // Create a model with the specified state
        let model = Model.preview
        model.state = modelState
        
        // Create the message with basic properties
        let message = Message(
            userInput: userInput,
            chat: chat,
            languageModelConfiguration: LLMConfiguration.preview,
            languageModel: model,
            imageModel: .preview
        )
        
        // Create Channel entities from response and thinking
        var channelEntities: [Channel] = []
        var order = 0
        
        if let thinking = thinking {
            let analysisChannel = Channel(
                type: .analysis,
                content: thinking,
                order: order
            )
            analysisChannel.message = message
            channelEntities.append(analysisChannel)
            order += 1
        }
        
        if let response = response {
            let finalChannel = Channel(
                type: .final,
                content: response,
                order: order
            )
            finalChannel.message = message
            channelEntities.append(finalChannel)
        }
        
        // Assign channels to message if any were created
        if !channelEntities.isEmpty {
            message.channels = channelEntities
        }

        // Add attachments as needed
        if withUserImage {
            message.userImage = ImageAttachment.preview
        }

        if withResponseImage {
            message.responseImage = ImageAttachment.preview
        }

        if withFile {
            message.file = [FileAttachment.preview]
        }

        return message
    }
}
#endif
