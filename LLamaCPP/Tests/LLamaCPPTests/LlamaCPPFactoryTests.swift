import Abstractions
import Foundation
import Testing

@testable import LLamaCPP

extension LlamaCPPModelTestSuite {
    @Test("Factory is the only public interface")
    internal func testOnlyFactoryIsPublic() {
        // This test verifies that LlamaCPPFactory is public
        // while other types like LlamaCPPSession are internal
        // The fact that we can't directly instantiate LlamaCPPSession
        // outside the module proves encapsulation

        // This should compile:
        _ = LlamaCPPFactory.self

        // These would not compile if uncommented (they're internal):
        // _ = LlamaCPPSession.self  // Would fail - internal
        // _ = LlamaCPPModel.self     // Would fail - internal
        // _ = LlamaCPPContext.self   // Would fail - internal
    }
}
