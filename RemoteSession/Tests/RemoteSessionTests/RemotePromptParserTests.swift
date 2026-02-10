import Testing
@testable import RemoteSession

@Suite("Remote Prompt Parser Tests")
struct RemotePromptParserTests {
    @Test("Parses Harmony system/user messages")
    func parsesHarmonyMessages() throws {
        let prompt = """
        <|start|>system<|message|>You are helpful.<|end|><|start|>user<|message|>Hello<|end|>
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[0].content.contains("You are helpful."))
        #expect(messages[1].role == .user)
        #expect(messages[1].content == "Hello")
    }

    @Test("Parses Harmony assistant channel messages")
    func parsesHarmonyAssistantChannelMessages() throws {
        let prompt = """
        <|start|>system<|message|>S<|end|><|start|>assistant<|channel|>final<|message|>Hi<|end|>
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count == 2)
        #expect(messages[1].role == .assistant)
        #expect(messages[1].content == "Hi")
    }

    @Test("Ignores trailing start token without message")
    func ignoresTrailingStartToken() throws {
        let prompt = """
        <|start|>system<|message|>S<|end|><|start|>assistant
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count == 1)
        #expect(messages[0].role == .system)
    }

    @Test("Parses ChatML system/user messages")
    func parsesChatMLMessages() throws {
        let prompt = """
        <|im_start|>system
        You are helpful.<|im_end|><|im_start|>user
        Hello<|im_end|>
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
        #expect(messages[1].content.contains("Hello"))
    }

    @Test("Parses Llama3 header messages")
    func parsesLlama3Messages() throws {
        let prompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\nS<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>\n\nU<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>\n\nA<|eot_id|>
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count == 3)
        #expect(messages[0].role == .system)
        #expect(messages[0].content == "S")
        #expect(messages[1].role == .user)
        #expect(messages[1].content == "U")
        #expect(messages[2].role == .assistant)
        #expect(messages[2].content == "A")
    }

    @Test("Parses Mistral [INST] blocks")
    func parsesMistralInstMessages() throws {
        let prompt = """
        [INST] Hello [/INST]Hi there.[INST] How are you? [/INST]
        """
        let messages = try #require(RemotePromptParser.parseMessages(from: prompt))
        #expect(messages.count >= 2)
        #expect(messages[0].role == .user)
        #expect(messages[0].content.contains("Hello"))
    }
}
