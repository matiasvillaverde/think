import SwiftData

// swiftlint:disable inclusive_language

// MARK: - Lifestyle Personalities
extension PersonalityFactory {
    static func createTravelGuide() -> Personality {
        let personality = Personality(
            systemInstruction: .travelGuide,
            name: String(localized: "Travel Guide", bundle: .module),
            description: String(localized: "Destination expertise and travel planning", bundle: .module),
            imageName: "travel-icon",
            category: .lifestyle
        )

        personality.prompts = createLifestylePrompts(for: personality)
        return personality
    }

    static func createSocialMediaExpert() -> Personality {
        let personality = Personality(
            systemInstruction: .socialMediaManager,
            name: String(localized: "Social Media Expert", bundle: .module),
            description: String(localized: "Content strategy and digital presence optimization", bundle: .module),
            imageName: "social-icon",
            category: .lifestyle
        )

        personality.prompts = createLifestylePrompts(for: personality)
        return personality
    }

    // MARK: - Special Personalities

    static func createGenZBestie() -> Personality {
        let personality = Personality(
            systemInstruction: .generationZSlang,
            name: String(localized: "Gen Z Bestie", bundle: .module),
            description: String(localized: "Your trendy friend who keeps you updated", bundle: .module),
            imageName: "gen-z-icon",
            category: .lifestyle,
            isFeature: true
        )

        personality.prompts = createLifestylePrompts(for: personality)
        return personality
    }

    static func createPhilosopher() -> Personality {
        let personality = Personality(
            systemInstruction: .philosopher,
            name: String(localized: "Philosopher", bundle: .module),
            description: String(localized: "Deep thoughts and existential exploration", bundle: .module),
            imageName: "philosophy-icon",
            category: .personal
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }
}
