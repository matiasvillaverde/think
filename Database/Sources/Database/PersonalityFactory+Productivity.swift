import SwiftData

// MARK: - Productivity Personalities
extension PersonalityFactory {
    static func createGeneralAssistant() -> Personality {
        let personality = Personality(
            systemInstruction: .englishAssistant,
            name: String(localized: "General Assistant", bundle: .module),
            description: String(localized: "A helpful and knowledgeable assistant for everyday tasks", bundle: .module),
            imageName: "think",
            category: .productivity,
            isFeature: true,
            isDefault: true
        )

        personality.prompts = createProductivityPrompts(for: personality)
        return personality
    }

    static func createCodeReviewer() -> Personality {
        let personality = Personality(
            systemInstruction: .codeReviewer,
            name: String(localized: "Code Reviewer", bundle: .module),
            description: String(localized: "Expert code analysis and improvement suggestions", bundle: .module),
            imageName: "code-review-icon",
            category: .productivity,
            isFeature: true
        )

        personality.prompts = createProductivityPrompts(for: personality)
        return personality
    }

    static func createCyberSecuritySpecialist() -> Personality {
        let personality = Personality(
            systemInstruction: .cyberSecuritySpecialist,
            name: String(localized: "Security Expert", bundle: .module),
            description: String(localized: "Cybersecurity guidance and threat assessment", bundle: .module),
            imageName: "security-icon",
            category: .productivity
        )

        personality.prompts = createProductivityPrompts(for: personality)
        return personality
    }
}
