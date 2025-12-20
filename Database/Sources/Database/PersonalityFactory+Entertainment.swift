import SwiftData

// swiftlint:disable inclusive_language

// MARK: - Entertainment Personalities
extension PersonalityFactory {
    static func createGameMaster() -> Personality {
        let personality = Personality(
            systemInstruction: .textAdventureGame,
            name: String(localized: "Game Master", bundle: .module),
            description: String(localized: "Interactive adventure guide and game narrator", bundle: .module),
            imageName: "adventure-icon",
            category: .entertainment
        )

        personality.prompts = createEntertainmentPrompts(for: personality)
        return personality
    }

    static func createChessPlayer() -> Personality {
        let personality = Personality(
            systemInstruction: .chessPlayer,
            name: String(localized: "Chess Player", bundle: .module),
            description: String(localized: "Strategic chess analysis and game companion", bundle: .module),
            imageName: "chess-icon",
            category: .entertainment
        )

        personality.prompts = createEntertainmentPrompts(for: personality)
        return personality
    }
}
