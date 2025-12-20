import Testing
import Foundation
@testable import Database

@Suite("Simple Personality Duplicate Prevention")
struct SimplePersonalityPreventionTests {
    @Test("PersonalityFactory should not create internal duplicates")
    func testFactoryCreatesNoDuplicates() {
        // When - Create personalities from factory
        let personalities = PersonalityFactory.createSystemPersonalities()
        
        // Then - Should have no duplicates
        let systemInstructions = personalities.map(\.systemInstruction)
        let uniqueInstructions = Set(systemInstructions)
        
        #expect(systemInstructions.count == uniqueInstructions.count)
        #expect(!personalities.isEmpty, "Factory should create some personalities")
    }
}
