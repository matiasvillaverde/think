import Foundation
import Testing
@testable import RemoteSession

@Suite("ErrorResponseParser Tests")
struct ErrorResponseParserTests {
    @Test("OpenAI parser extracts message when code is an Int")
    func openAIErrorWithIntCode() throws {
        let data = Data(#"{"error":{"message":"No cookie auth credentials found","code":401}}"#.utf8)
        let parsed = ErrorResponseParser.parseOpenAI(data, statusCode: 401)

        #expect(parsed.statusCode == 401)
        #expect(parsed.message == "No cookie auth credentials found")
        #expect(parsed.errorType == "401")
    }
}
