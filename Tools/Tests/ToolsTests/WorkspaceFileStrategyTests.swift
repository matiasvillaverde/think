import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("WorkspaceFileStrategy Tests")
internal struct WorkspaceFileStrategyTests {
    @Test("Write then read returns same content")
    func writeThenRead() async {
        let root: URL = makeTempDirectory()
        let strategy: WorkspaceFileStrategy = WorkspaceFileStrategy(rootURL: root)

        let writeRequest: ToolRequest = ToolRequest(
            name: "workspace",
            arguments: "{\"action\":\"write\",\"path\":\"notes/test.txt\",\"content\":\"hello\"}"
        )
        let writeResponse: ToolResponse = await strategy.execute(request: writeRequest)
        #expect(writeResponse.error == nil)

        let readRequest: ToolRequest = ToolRequest(
            name: "workspace",
            arguments: "{\"action\":\"read\",\"path\":\"notes/test.txt\"}"
        )
        let readResponse: ToolResponse = await strategy.execute(request: readRequest)
        #expect(readResponse.result == "hello")
    }

    @Test("List returns created file")
    func listReturnsCreatedFile() async {
        let root: URL = makeTempDirectory()
        let strategy: WorkspaceFileStrategy = WorkspaceFileStrategy(rootURL: root)

        let writeRequest: ToolRequest = ToolRequest(
            name: "workspace",
            arguments: "{\"action\":\"write\",\"path\":\"notes/test.txt\",\"content\":\"hello\"}"
        )
        _ = await strategy.execute(request: writeRequest)

        let listRequest: ToolRequest = ToolRequest(
            name: "workspace",
            arguments: "{\"action\":\"list\",\"path\":\".\",\"recursive\":true}"
        )
        let listResponse: ToolResponse = await strategy.execute(request: listRequest)
        #expect(listResponse.error == nil)

        let data: Data = listResponse.result.data(using: .utf8) ?? Data()
        let decoded: [String] = (try? JSONSerialization.jsonObject(with: data)) as? [String] ?? []
        #expect(decoded.contains("notes/test.txt"))
    }

    @Test("Path traversal is rejected")
    func pathTraversalRejected() async {
        let root: URL = makeTempDirectory()
        let strategy: WorkspaceFileStrategy = WorkspaceFileStrategy(rootURL: root)

        let readRequest: ToolRequest = ToolRequest(
            name: "workspace",
            arguments: "{\"action\":\"read\",\"path\":\"../secret.txt\"}"
        )
        let response: ToolResponse = await strategy.execute(request: readRequest)
        #expect(response.error != nil)
    }

    private func makeTempDirectory() -> URL {
        let url: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
