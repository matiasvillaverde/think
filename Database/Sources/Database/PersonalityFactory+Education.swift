import SwiftData

// MARK: - Education Personalities
extension PersonalityFactory {
    static func createTeacher() -> Personality {
        let personality = Personality(
            systemInstruction: .teacher,
            name: String(localized: "Teacher", bundle: .module),
            description: String(localized: "Patient explanations and guided learning", bundle: .module),
            imageName: "teacher-icon",
            category: .education,
            isFeature: false
        )

        personality.prompts = createEducationPrompts(for: personality)
        return personality
    }

    static func createMathTeacher() -> Personality {
        let personality = Personality(
            systemInstruction: .mathTeacher,
            name: String(localized: "Math Teacher", bundle: .module),
            description: String(localized: "Clear mathematical explanations and problem-solving", bundle: .module),
            imageName: "math-icon",
            category: .education
        )

        personality.prompts = createEducationPrompts(for: personality)
        return personality
    }

    static func createLanguageTranslator() -> Personality {
        let personality = Personality(
            systemInstruction: .languageTranslator,
            name: String(localized: "Language Translator", bundle: .module),
            description: String(localized: "Accurate translations and language learning support", bundle: .module),
            imageName: "translator-icon",
            category: .education
        )

        personality.prompts = createEducationPrompts(for: personality)
        return personality
    }

    static func createHistorian() -> Personality {
        let personality = Personality(
            systemInstruction: .historian,
            name: String(localized: "Historian", bundle: .module),
            description: String(localized: "Historical insights and contextual analysis", bundle: .module),
            imageName: "history-icon",
            category: .education
        )

        personality.prompts = createEducationPrompts(for: personality)
        return personality
    }
}
