import Foundation
@testable import Rag
import Testing

@Suite("SupportedFileType")
internal struct SupportedFileTypeTests {
    @Test("Detects supported extensions case-insensitively")
    func testDetectsExtensionsCaseInsensitive() {
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file.TXT")) == .text)
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file.PdF")) == .pdf)
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file.CsV")) == .csv)
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file.JsOn")) == .json)
    }

    @Test("Detects markdown aliases")
    func testDetectsMarkdownAliases() {
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/readme.md")) == .markdown)
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/readme.markdown")) == .markdown)
    }

    @Test("Returns nil for unsupported extensions")
    func testUnsupportedExtensionReturnsNil() {
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file.exe")) == nil)
        #expect(SupportedFileType.detect(from: URL(fileURLWithPath: "/tmp/file")) == nil)
    }

    @Test("Debug description matches case")
    func testDebugDescriptionMatchesCase() {
        #expect(SupportedFileType.csv.debugDescription == "csv")
        #expect(SupportedFileType.docx.debugDescription == "docx")
        #expect(SupportedFileType.json.debugDescription == "json")
        #expect(SupportedFileType.markdown.debugDescription == "markdown")
        #expect(SupportedFileType.pdf.debugDescription == "pdf")
        #expect(SupportedFileType.text.debugDescription == "text")
    }
}
