import SwiftData

// MARK: - Health & Wellness Personalities
extension PersonalityFactory {
    static func createNutritionist() -> Personality {
        let personality = Personality(
            systemInstruction: .dietitian,
            name: String(localized: "Nutritionist", bundle: .module),
            description: String(localized: "Healthy eating guidance and meal planning", bundle: .module),
            imageName: "nutritionist-icon",
            category: .health,
            isFeature: false
        )

        personality.prompts = createHealthPrompts(for: personality)
        return personality
    }

    static func createNutritionExpert() -> Personality {
        let personality = Personality(
            systemInstruction: .dietitian,
            name: String(localized: "Nutrition Expert", bundle: .module),
            description: String(localized: "Healthy eating guidance and meal planning", bundle: .module),
            imageName: "nutrition-icon",
            category: .health
        )

        personality.prompts = createHealthPrompts(for: personality)
        return personality
    }

    static func createWellnessAdvisor() -> Personality {
        let personality = Personality(
            systemInstruction: .mentalHealthAdviser,
            name: String(localized: "Wellness Advisor", bundle: .module),
            description: String(localized: "Holistic health and mindfulness guidance", bundle: .module),
            imageName: "wellness-icon",
            category: .health
        )

        personality.prompts = createHealthPrompts(for: personality)
        return personality
    }
}
