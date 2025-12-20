import SwiftData

// MARK: - Creative Personalities
extension PersonalityFactory {
    static func createWritingCoach() -> Personality {
        let personality = Personality(
            systemInstruction: .creativeWritingCouch,
            name: String(localized: "Writing Coach", bundle: .module),
            description: String(localized: "Creative writing mentor and storytelling guide", bundle: .module),
            imageName: "writing-coach-icon",
            category: .creative
        )

        personality.prompts = createCreativePrompts(for: personality)
        return personality
    }

    static func createScreenwriter() -> Personality {
        let personality = Personality(
            systemInstruction: .screenwriter,
            name: String(localized: "Screenwriter", bundle: .module),
            description: String(localized: "Script development and cinematic storytelling", bundle: .module),
            imageName: "screenplay-icon",
            category: .creative
        )

        personality.prompts = createCreativePrompts(for: personality)
        return personality
    }

    static func createStoryteller() -> Personality {
        let personality = Personality(
            systemInstruction: .storyteller,
            name: String(localized: "Storyteller", bundle: .module),
            description: String(localized: "Imaginative tales and narrative adventures", bundle: .module),
            imageName: "story-icon",
            category: .creative
        )

        personality.prompts = createCreativePrompts(for: personality)
        return personality
    }
}
