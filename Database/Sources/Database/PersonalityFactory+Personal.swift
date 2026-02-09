import SwiftData

// MARK: - Personal Personalities
extension PersonalityFactory {
    static func createSupportiveFriend() -> Personality {
        let personality = Personality(
            systemInstruction: .empatheticFriend,
            name: String(localized: "Supportive Friend", bundle: .module),
            description: String(localized: "Empathetic listener and emotional support", bundle: .module),
            imageName: "friend-icon",
            category: .personal,
            isFeature: true
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }

    static func createMother() -> Personality {
        let personality = Personality(
            systemInstruction: .mother,
            name: String(localized: "Mother", bundle: .module),
            description: String(localized: "Warm, grounding support and practical care", bundle: .module),
            imageName: "mother-icon",
            category: .personal
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }

    static func createFather() -> Personality {
        let personality = Personality(
            systemInstruction: .father,
            name: String(localized: "Father", bundle: .module),
            description: String(localized: "Steady guidance, clear plans, and follow-through", bundle: .module),
            imageName: "father-icon",
            category: .personal
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }

    static func createRelationshipAdvisor() -> Personality {
        let personality = Personality(
            systemInstruction: .relationshipAdvisor,
            name: String(localized: "Relationship Advisor", bundle: .module),
            description: String(localized: "Thoughtful guidance for personal connections", bundle: .module),
            imageName: "relationship-icon",
            category: .personal
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }

    static func createLifeCoach() -> Personality {
        let personality = Personality(
            systemInstruction: .lifeCoach,
            name: String(localized: "Life Coach", bundle: .module),
            description: String(localized: "Goal-setting and personal development mentor", bundle: .module),
            imageName: "coach-icon",
            category: .personal,
            isFeature: true
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }

    static func createSupportivePsychologist() -> Personality {
        let personality = Personality(
            systemInstruction: .supportivePsychologist,
            name: String(localized: "Psychologist", bundle: .module),
            description: String(localized: "Gentle, evidence-informed mental health support", bundle: .module),
            imageName: "psychologist-icon",
            category: .personal,
            isFeature: true
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }
}
