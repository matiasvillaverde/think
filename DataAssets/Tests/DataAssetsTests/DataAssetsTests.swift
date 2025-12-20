import Testing
@testable import DataAssets

@Suite("DataAssets Module Tests")
struct DataAssetsTests {
    @Test("Module can be imported and has version")
    func testModuleImport() {
        #expect(DataAssets.version == "1.0.0")
    }
}