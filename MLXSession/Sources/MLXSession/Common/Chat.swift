internal enum Chat {
    internal struct Message {
        internal var role: Role
        internal var content: String
        internal var images: [UserInput.Image]
        internal var videos: [UserInput.Video]

        internal init(
            role: Role,
            content: String,
            images: [UserInput.Image] = [],
            videos: [UserInput.Video] = []
        ) {
            self.role = role
            self.content = content
            self.images = images
            self.videos = videos
        }

        internal static func system(
            _ content: String,
            images: [UserInput.Image] = [],
            videos: [UserInput.Video] = []
        ) -> Self {
            Self(role: .system, content: content, images: images, videos: videos)
        }

        internal static func assistant(
            _ content: String,
            images: [UserInput.Image] = [],
            videos: [UserInput.Video] = []
        ) -> Self {
            Self(role: .assistant, content: content, images: images, videos: videos)
        }

        internal static func user(
            _ content: String,
            images: [UserInput.Image] = [],
            videos: [UserInput.Video] = []
        ) -> Self {
            Self(role: .user, content: content, images: images, videos: videos)
        }

        internal static func tool(_ content: String) -> Self {
            Self(role: .tool, content: content)
        }

        internal enum Role: String, Sendable {
            case user
            case assistant
            case system
            case tool
        }
    }
}

internal protocol MessageGenerator: Sendable {
    func generate(from input: UserInput) -> [Message]
    func generate(messages: [Chat.Message]) -> [Message]
    func generate(message: Chat.Message) -> Message
}

extension MessageGenerator {
    internal func generate(message: Chat.Message) -> Message {
        [
            "role": message.role.rawValue,
            "content": message.content,
        ]
    }

    internal func generate(messages: [Chat.Message]) -> [Message] {
        var rawMessages: [Message] = []
        for message in messages {
            rawMessages.append(generate(message: message))
        }
        return rawMessages
    }

    internal func generate(from input: UserInput) -> [Message] {
        switch input.prompt {
        case .text(let text):
            generate(messages: [.user(text)])
        case .messages(let messages):
            messages
        case .chat(let messages):
            generate(messages: messages)
        }
    }
}

internal struct DefaultMessageGenerator: MessageGenerator {
    internal init() {}

    internal func generate(message: Chat.Message) -> Message {
        [
            "role": message.role.rawValue,
            "content": message.content,
        ]
    }
}

internal struct NoSystemMessageGenerator: MessageGenerator {
    internal init() {}

    internal func generate(messages: [Chat.Message]) -> [Message] {
        messages
            .filter { $0.role != .system }
            .map { generate(message: $0) }
    }
}

/// Message generator for Qwen2VL-style chat templates with structured content.
internal struct Qwen2VLMessageGenerator: MessageGenerator {
    internal init() {}

    internal func generate(message: Chat.Message) -> Message {
        [
            "role": message.role.rawValue,
            "content": [
                ["type": "text", "text": message.content]
            ]
                + message.images.map { _ in ["type": "image"] }
                + message.videos.map { _ in ["type": "video"] },
        ]
    }
}
