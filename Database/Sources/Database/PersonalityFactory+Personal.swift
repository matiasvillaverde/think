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
            category: .personal
        )

        personality.prompts = createPersonalPrompts(for: personality)
        return personality
    }
}
