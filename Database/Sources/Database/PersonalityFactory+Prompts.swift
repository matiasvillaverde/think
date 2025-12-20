import SwiftData

// swiftlint:disable line_length

// MARK: - Prompt Creators
extension PersonalityFactory {
    static func createProductivityPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Code Review Assistant", bundle: .module),
                subtitle: String(localized: "analyze and improve code quality", bundle: .module),
                prompt: String(localized: "Review this code for potential bugs, performance issues, and best practices. Provide specific suggestions for improvement with explanations.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Project Management Plan", bundle: .module),
                subtitle: String(localized: "organize tasks and timelines", bundle: .module),
                prompt: String(localized: "Help me create a detailed project plan for launching a mobile app, including milestones, resource allocation, and risk management strategies.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Professional Email Templates", bundle: .module),
                subtitle: String(localized: "effective business communication", bundle: .module),
                prompt: String(localized: "Write a professional email template for following up on a job interview, including key points to emphasize and appropriate tone.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Cybersecurity Assessment", bundle: .module),
                subtitle: String(localized: "identify security vulnerabilities", bundle: .module),
                prompt: String(localized: "Analyze my company's current security practices and suggest improvements for protecting against common cyber threats.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Meeting Agenda Builder", bundle: .module),
                subtitle: String(localized: "structured productive meetings", bundle: .module),
                prompt: String(localized: "Create a comprehensive agenda for a quarterly business review meeting, including time allocations and discussion topics.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createCreativePrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Character Development Workshop", bundle: .module),
                subtitle: String(localized: "build compelling personas", bundle: .module),
                prompt: String(localized: "Create a detailed character profile for a fantasy novel protagonist, including backstory, personality flaws, goals, and character arc.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Screenplay Scene Creator", bundle: .module),
                subtitle: String(localized: "cinematic storytelling", bundle: .module),
                prompt: String(localized: "Write an opening scene for a thriller movie set in a small coastal town, focusing on visual storytelling and atmosphere.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Creative Writing Prompt Generator", bundle: .module),
                subtitle: String(localized: "spark imagination", bundle: .module),
                prompt: String(localized: "Generate 10 unique writing prompts for short stories, each with an interesting premise and potential conflict.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Plot Twist Designer", bundle: .module),
                subtitle: String(localized: "unexpected story elements", bundle: .module),
                prompt: String(localized: "Create 5 surprising but believable plot twists for a mystery novel about a missing person case.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Dialogue Polisher", bundle: .module),
                subtitle: String(localized: "natural conversation flow", bundle: .module),
                prompt: String(localized: "Improve this dialogue to make it sound more natural and reveal character traits through speech patterns and word choices.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createEducationPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Concept Explainer", bundle: .module),
                subtitle: String(localized: "complex ideas made simple", bundle: .module),
                prompt: String(localized: "Explain quantum computing to a 10-year-old using simple analogies and examples they can relate to.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Study Plan Creator", bundle: .module),
                subtitle: String(localized: "structured learning approach", bundle: .module),
                prompt: String(localized: "Create a 6-week study plan for learning calculus, including daily tasks, practice problems, and progress milestones.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Language Learning Assistant", bundle: .module),
                subtitle: String(localized: "master new languages", bundle: .module),
                prompt: String(localized: "Help me learn Spanish by creating a conversation practice scenario for ordering food at a restaurant.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Historical Analysis", bundle: .module),
                subtitle: String(localized: "understand past events", bundle: .module),
                prompt: String(localized: "Analyze the causes and effects of the French Revolution, focusing on economic, social, and political factors.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Math Problem Solver", bundle: .module),
                subtitle: String(localized: "step-by-step solutions", bundle: .module),
                prompt: String(localized: "Solve this algebra problem step by step, explaining each operation and the reasoning behind it.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createEntertainmentPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Text Adventure Creator", bundle: .module),
                subtitle: String(localized: "interactive storytelling", bundle: .module),
                prompt: String(localized: "Start a text-based adventure game where I'm exploring an abandoned space station. Set the scene and present my first choices.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Chess Strategy Coach", bundle: .module),
                subtitle: String(localized: "improve your game", bundle: .module),
                prompt: String(localized: "Analyze this chess position and suggest the best moves for both sides, explaining the strategic reasoning.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Trivia Game Master", bundle: .module),
                subtitle: String(localized: "challenging questions", bundle: .module),
                prompt: String(localized: "Create a 10-question trivia game about 80s movies, with multiple choice answers and interesting facts about each film.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Riddle Generator", bundle: .module),
                subtitle: String(localized: "brain-teasing puzzles", bundle: .module),
                prompt: String(localized: "Create 5 original riddles of varying difficulty levels, from easy wordplay to challenging logic puzzles.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Story Game Facilitator", bundle: .module),
                subtitle: String(localized: "collaborative storytelling", bundle: .module),
                prompt: String(localized: "Start a collaborative story where each person adds one sentence. Begin with an intriguing opening line.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createHealthPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Nutrition Plan Designer", bundle: .module),
                subtitle: String(localized: "balanced meal planning", bundle: .module),
                prompt: String(localized: "Create a week-long meal plan for someone trying to eat more plant-based foods while maintaining adequate protein.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Workout Routine Builder", bundle: .module),
                subtitle: String(localized: "personalized fitness plans", bundle: .module),
                prompt: String(localized: "Design a 4-week beginner strength training program that can be done at home with minimal equipment.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Wellness Goal Setting", bundle: .module),
                subtitle: String(localized: "holistic health approach", bundle: .module),
                prompt: String(localized: "Help me create realistic wellness goals for improving sleep, stress management, and physical activity over the next 3 months.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Mindfulness Practice Guide", bundle: .module),
                subtitle: String(localized: "mental health support", bundle: .module),
                prompt: String(localized: "Guide me through a 10-minute mindfulness exercise for reducing anxiety and improving focus.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Healthy Habit Tracker", bundle: .module),
                subtitle: String(localized: "build positive routines", bundle: .module),
                prompt: String(localized: "Create a habit tracking system to help me establish a morning routine that includes exercise, meditation, and healthy breakfast.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createPersonalPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Relationship Communication", bundle: .module),
                subtitle: String(localized: "strengthen connections", bundle: .module),
                prompt: String(localized: "Help me have a difficult conversation with my partner about household responsibilities in a constructive way.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Personal Growth Reflection", bundle: .module),
                subtitle: String(localized: "self-improvement journey", bundle: .module),
                prompt: String(localized: "Guide me through a self-reflection exercise to identify my core values and how they align with my current life choices.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Confidence Building Coach", bundle: .module),
                subtitle: String(localized: "overcome self-doubt", bundle: .module),
                prompt: String(localized: "Help me prepare for a job interview by building confidence and practicing responses to challenging questions.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Life Goal Strategist", bundle: .module),
                subtitle: String(localized: "achieve your dreams", bundle: .module),
                prompt: String(localized: "Break down my long-term goal of starting my own business into manageable monthly and weekly action steps.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Emotional Support Friend", bundle: .module),
                subtitle: String(localized: "caring conversation", bundle: .module),
                prompt: String(localized: "I'm feeling overwhelmed with work and personal responsibilities. Help me process these feelings and find ways to cope.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Decision Making Guide", bundle: .module),
                subtitle: String(localized: "clarity in choices", bundle: .module),
                prompt: String(localized: "Help me weigh the pros and cons of a major life decision using a structured decision-making framework.", bundle: .module),
                personality: personality
            )
        ]
    }

    static func createLifestylePrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Travel Itinerary Planner", bundle: .module),
                subtitle: String(localized: "memorable adventures", bundle: .module),
                prompt: String(localized: "Plan a 7-day trip to Japan focusing on traditional culture, local cuisine, and unique experiences beyond tourist hotspots.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Social Media Strategy", bundle: .module),
                subtitle: String(localized: "engaging content creation", bundle: .module),
                prompt: String(localized: "Develop a content calendar for a small bakery's Instagram account, including post ideas, hashtags, and engagement strategies.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Home Organization System", bundle: .module),
                subtitle: String(localized: "declutter and organize", bundle: .module),
                prompt: String(localized: "Create a room-by-room organization plan for a small apartment, including storage solutions and maintenance routines.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Budget Planning Assistant", bundle: .module),
                subtitle: String(localized: "financial goal setting", bundle: .module),
                prompt: String(localized: "Help me create a monthly budget that allows for saving 20% of income while maintaining a comfortable lifestyle.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Weekend Activity Generator", bundle: .module),
                subtitle: String(localized: "local exploration ideas", bundle: .module),
                prompt: String(localized: "Suggest unique weekend activities in my city that are budget-friendly and good for meeting new people.", bundle: .module),
                personality: personality
            )
        ]
    }
}
