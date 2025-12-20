import Abstractions
@testable import ModelDownloader
import Testing

@Suite("FileSelectorFactory Tests")
struct FileSelectorFactoryTests {
    @Test("Creates MLX selector")
    func createsMLXSelector() async {
        let factory: FileSelectorFactory = FileSelectorFactory.shared
        let selector: FileSelectorProtocol? = await factory.createSelector(for: .mlx)
        #expect(selector != nil)
    }
}
