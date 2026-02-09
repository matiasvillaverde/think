import Testing
import Foundation
import Abstractions
@testable import Database

/// Tests for PersonalityFactory featured personalities
@Suite("PersonalityFactory Featured Personalities Tests")
struct PersonalityFactoryFeaturedTests {
    @Test("Factory creates the expected number of featured personalities")
    func factoryCreatesExpectedFeaturedPersonalitiesCount() {
        // Given/When
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        // Then
        #expect(featuredPersonalities.count == 7, """
            Expected exactly 7 featured personalities, but found \(featuredPersonalities.count).
            Featured: \(featuredPersonalities.map(\.name))
            """)
    }

    @Test("Featured personalities include correct set")
    func featuredPersonalitiesIncludeCorrectSet() {
        // Given
        let expectedFeaturedNames: Set<String> = [
            "General Assistant",
            "Supportive Friend",
            "Work Coach",
            "Life Coach",
            "Psychologist",
            "Teacher",
            "Nutritionist"
        ]

        // When
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }
        let featuredNames: Set<String> = Set(featuredPersonalities.map(\.name))

        // Then
        #expect(featuredNames == expectedFeaturedNames)
    }

    @Test("Featured personalities are editable")
    func featuredPersonalitiesAreEditable() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        // Then
        for personality in featuredPersonalities {
            #expect(personality.isEditable, "Featured personality '\(personality.name)' should be editable")
        }
    }

    @Test("Non-featured personalities still work")
    func nonFeaturedPersonalitiesStillWork() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()
        let nonFeaturedPersonalities: [Personality] = personalities.filter { !$0.isFeature }

        // Then
        #expect(!nonFeaturedPersonalities.isEmpty, "There should be non-featured personalities")

        for personality in nonFeaturedPersonalities {
            #expect(!personality.name.isEmpty, "Personality name should not be empty")
            #expect(!personality.displayDescription.isEmpty, "Personality description should not be empty")
        }
    }

    @Test("General Assistant is featured and is the default")
    func generalAssistantIsFeaturedAndDefault() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()

        // When
        let generalAssistant: Personality? = personalities.first { $0.name == "General Assistant" }

        // Then
        #expect(generalAssistant != nil, "General Assistant should exist")
        #expect(generalAssistant?.isFeature == true, "General Assistant should be featured")
        #expect(generalAssistant?.isDefault == true, "General Assistant should be the default")
    }

    @Test("All personalities have unique system instructions")
    func allPersonalitiesHaveUniqueSystemInstructions() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()

        // When
        let instructions: [String] = personalities.map(\.systemInstruction.rawValue)
        let uniqueInstructions: Set<String> = Set(instructions)

        // Then
        #expect(instructions.count == uniqueInstructions.count, """
            Duplicate system instructions found.
            Total: \(instructions.count), Unique: \(uniqueInstructions.count)
            """)
    }

    @Test("Featured personalities span different categories")
    func featuredPersonalitiesSpanDifferentCategories() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        // When
        let categories: Set<PersonalityCategory> = Set(featuredPersonalities.map(\.category))

        // Then - We expect at least 3 different categories
        #expect(categories.count >= 3, """
            Featured personalities should span at least 3 categories.
            Categories found: \(categories)
            """)
    }

    @Test("Total system personalities count")
    func totalSystemPersonalitiesCount() {
        // Given
        let personalities: [Personality] = PersonalityFactory.createSystemPersonalities()

        #expect(personalities.count == 10)
    }
}
