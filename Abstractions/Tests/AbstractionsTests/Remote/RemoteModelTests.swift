import Abstractions
import Testing

@Suite("RemoteModel Tests")
struct RemoteModelTests {
    @Test("RemoteModel location uses lowercase provider prefix")
    func remoteModelLocationUsesLowercasePrefix() {
        let model = RemoteModel(
            provider: .openRouter,
            modelId: "openai/gpt-4o-mini",
            displayName: "GPT-4o Mini"
        )

        #expect(model.location == "openrouter:openai/gpt-4o-mini")
        #expect(model.id == model.location)
    }
}
