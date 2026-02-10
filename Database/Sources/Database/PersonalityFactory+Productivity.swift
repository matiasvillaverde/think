import SwiftData

// MARK: - Productivity Personalities
extension PersonalityFactory {
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

    static func createWorkCoach() -> Personality {
        let personality = Personality(
            systemInstruction: .workCoach,
            name: String(localized: "Work Coach", bundle: .module),
            description: String(localized: "Turn goals into next steps, plans, and drafts", bundle: .module),
            imageName: "work-coach-icon",
            category: .productivity,
            isFeature: false
        )

        personality.prompts = createProductivityPrompts(for: personality)
        return personality
    }

    static func createButler() -> Personality {
        let personality = Personality(
            systemInstruction: .butler,
            name: String(localized: "Butler", bundle: .module),
            description: String(localized: "Polished planning, reminders, and tasteful wording", bundle: .module),
            imageName: "butler-icon",
            category: .productivity,
            isFeature: true
        )

        personality.prompts = createProductivityPrompts(for: personality)
        return personality
    }
}
