import SwiftData
import Abstractions
import DataAssets

// swiftlint:disable line_length inclusive_language

internal class PersonalityFactory {
    /// Creates all default system personalities with their associated prompts
    /// - Returns: Array of unique system personalities
    /// - Throws: Precondition failure if duplicates detected in factory
    static func createSystemPersonalities() -> [Personality] {
        let personalities = [
            // Productivity
            createGeneralAssistant(),
            createCodeReviewer(),
            createCyberSecuritySpecialist(),

            // Creative
            createWritingCoach(),
            createScreenwriter(),
            createStoryteller(),

            // Education
            createMathTeacher(),
            createLanguageTranslator(),
            createHistorian(),

            // Entertainment
            createGameMaster(),
            createChessPlayer(),

            // Health & Wellness
            createNutritionExpert(),
            createWellnessAdvisor(),

            // Personal
            createSupportiveFriend(),
            createRelationshipAdvisor(),
            createLifeCoach(),

            // Lifestyle
            createTravelGuide(),
            createSocialMediaExpert(),

            // Special personalities
            createGenZBestie(),
            createPhilosopher()
        ]

        // VALIDATION: Ensure no duplicates in factory-created personalities
        validateFactoryPersonalities(personalities)
        
        return personalities
    }
    
    /// Safely gets or creates a system personality, preventing duplicates
    /// - Parameters:
    ///   - systemInstruction: The system instruction for the personality
    ///   - context: The ModelContext to use
    /// - Returns: Existing personality or newly created one
    /// - Throws: Database errors or validation errors
    static func getOrCreateSystemPersonality(
        systemInstruction: SystemInstruction,
        in context: ModelContext
    ) throws -> Personality {
        // Create new personality using factory method to get the name
        let personality = try createPersonalityForInstruction(systemInstruction)
        
        // Try to find existing system personality by name
        if let existing = try Personality.findExistingSystemPersonality(
            name: personality.name,
            in: context
        ) {
            return existing
        }
        
        // Safe insertion with final validation
        try insertSystemPersonalitySafely(personality, in: context)
        
        return personality
    }
    
    /// Validates that factory-created personalities have no duplicates
    /// - Parameter personalities: Array of personalities to validate
    /// - Throws: Precondition failure if duplicates found
    private static func validateFactoryPersonalities(_ personalities: [Personality]) {
        let systemInstructions = personalities.map(\.systemInstruction)
        let uniqueInstructions = Set(systemInstructions)
        
        precondition(
            systemInstructions.count == uniqueInstructions.count,
            """
            PersonalityFactory created duplicate personalities!
            Total: \(systemInstructions.count), Unique: \(uniqueInstructions.count)
            Duplicates: \(findDuplicates(in: systemInstructions))
            """
        )
    }
    
    /// Finds duplicate values in an array
    /// - Parameter array: Array to check for duplicates
    /// - Returns: Set of duplicate values
    private static func findDuplicates<T: Hashable>(in array: [T]) -> Set<T> {
        var seen: Set<T> = []
        var duplicates: Set<T> = []
        
        for item in array {
            if seen.contains(item) {
                duplicates.insert(item)
            } else {
                seen.insert(item)
            }
        }
        
        return duplicates
    }
    
    /// Creates a personality for a specific system instruction
    /// - Parameter instruction: The system instruction
    /// - Returns: A new personality instance
    /// - Throws: If the instruction is not supported
    private static func createPersonalityForInstruction(_ instruction: SystemInstruction) throws -> Personality {
        // Use lookup table to reduce complexity
        let personalityMap: [SystemInstruction: () -> Personality] = [
            .englishAssistant: createGeneralAssistant,
            .codeReviewer: createCodeReviewer,
            .cyberSecuritySpecialist: createCyberSecuritySpecialist,
            .creativeWritingCouch: createWritingCoach,
            .screenwriter: createScreenwriter,
            .storyteller: createStoryteller,
            .mathTeacher: createMathTeacher,
            .languageTranslator: createLanguageTranslator,
            .historian: createHistorian,
            .textAdventureGame: createGameMaster,
            .chessPlayer: createChessPlayer,
            .dietitian: createNutritionExpert,
            .mentalHealthAdviser: createWellnessAdvisor,
            .empatheticFriend: createSupportiveFriend,
            .relationshipAdvisor: createRelationshipAdvisor,
            .lifeCoach: createLifeCoach,
            .travelGuide: createTravelGuide,
            .socialMediaManager: createSocialMediaExpert,
            .generationZSlang: createGenZBestie,
            .philosopher: createPhilosopher
        ]
        
        guard let factory = personalityMap[instruction] else {
            throw PersonalityError.invalidSystemInstruction
        }
        
        return factory()
    }
    
    /// Safely inserts a system personality with duplicate protection
    /// - Parameters:
    ///   - personality: The personality to insert
    ///   - context: The ModelContext to use
    /// - Throws: PersonalityError if duplicate detected or database errors
    static func insertSystemPersonalitySafely(
        _ personality: Personality,
        in context: ModelContext
    ) throws {
        // Final validation: ensure no duplicate exists
        if try Personality.findExistingSystemPersonality(
            name: personality.name,
            in: context
        ) != nil {
            throw PersonalityError.duplicateSystemPersonality(
                name: personality.name,
                count: 2
            )
        }
        
        // Safe to insert
        context.insert(personality)
    }
}

// All personalities are now in extension files:
// - PersonalityFactory+Productivity.swift: General Assistant, Code Reviewer, Security Expert
// - PersonalityFactory+Creative.swift: Writing Coach, Screenwriter, Storyteller
// - PersonalityFactory+Education.swift: Math Teacher, Language Translator, Historian
// - PersonalityFactory+Entertainment.swift: Game Master, Chess Player
// - PersonalityFactory+Health.swift: Nutrition Expert, Wellness Advisor
// - PersonalityFactory+Personal.swift: Supportive Friend, Relationship Advisor, Life Coach
// - PersonalityFactory+Lifestyle.swift: Travel Guide, Social Media Expert, Gen Z Bestie, Philosopher
// - PersonalityFactory+Prompts.swift: All prompt creation methods
