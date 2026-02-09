import SwiftData

// swiftlint:disable line_length

// MARK: - Prompt Creators
extension PersonalityFactory {
    static func createPrompts(for personality: Personality) -> [Prompt] {
        switch personality.category {
        case .productivity:
            return createProductivityPrompts(for: personality)
        case .creative:
            return createCreativePrompts(for: personality)
        case .education:
            return createEducationPrompts(for: personality)
        case .entertainment:
            return createEntertainmentPrompts(for: personality)
        case .health:
            return createHealthPrompts(for: personality)
        case .personal:
            return createPersonalPrompts(for: personality)
        case .lifestyle:
            return createLifestylePrompts(for: personality)
        }
    }

    static func createProductivityPrompts(for personality: Personality) -> [Prompt] {
        [
            Prompt(
                title: String(localized: "Weekly Plan", bundle: .module),
                subtitle: String(localized: "prioritize and schedule", bundle: .module),
                prompt: String(localized: "Help me plan my week. My goals are: (1) __, (2) __. I have these constraints: __. Propose a realistic schedule and the first 3 next actions.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Write a Status Update", bundle: .module),
                subtitle: String(localized: "clear and concise", bundle: .module),
                prompt: String(localized: "Draft a short status update for my team. This week: __. Blockers: __. Next: __. Keep it crisp and action-oriented.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Decision Framework", bundle: .module),
                subtitle: String(localized: "make a call", bundle: .module),
                prompt: String(localized: "Help me decide between option A: __ and option B: __. My priorities are: __. Ask any key questions, then recommend one with reasons.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Email Draft", bundle: .module),
                subtitle: String(localized: "polished and respectful", bundle: .module),
                prompt: String(localized: "Draft an email to __ about __. Tone: __. Include these points: __.", bundle: .module),
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
                title: String(localized: "Practice Quiz", bundle: .module),
                subtitle: String(localized: "check understanding", bundle: .module),
                prompt: String(localized: "Quiz me on __ with 10 questions. Mix easy and hard. After each answer, explain what I got right or wrong.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Learn by Example", bundle: .module),
                subtitle: String(localized: "step-by-step", bundle: .module),
                prompt: String(localized: "Teach me __ using 3 examples. For each example: explain, then ask me to try a similar one.", bundle: .module),
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
                title: String(localized: "Grocery List", bundle: .module),
                subtitle: String(localized: "shop once", bundle: .module),
                prompt: String(localized: "Turn this meal plan into a grocery list grouped by aisle: __", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Wellness Goal Setting", bundle: .module),
                subtitle: String(localized: "holistic health approach", bundle: .module),
                prompt: String(localized: "Help me create realistic wellness goals for improving sleep, stress management, and physical activity over the next 3 months.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Protein Ideas", bundle: .module),
                subtitle: String(localized: "easy options", bundle: .module),
                prompt: String(localized: "I want high-protein meals with minimal cooking. Give me 10 options with approximate protein per serving.", bundle: .module),
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
                title: String(localized: "Talk It Out", bundle: .module),
                subtitle: String(localized: "sort feelings", bundle: .module),
                prompt: String(localized: "I’m feeling __ about __. Help me make sense of it and decide what to do next.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Personal Growth Reflection", bundle: .module),
                subtitle: String(localized: "self-improvement journey", bundle: .module),
                prompt: String(localized: "Guide me through a self-reflection exercise to identify my core values and how they align with my current life choices.", bundle: .module),
                personality: personality
            ),
            Prompt(
                title: String(localized: "Hard Conversation", bundle: .module),
                subtitle: String(localized: "say it well", bundle: .module),
                prompt: String(localized: "Help me have a difficult conversation with __ about __. I want to be kind and clear. Draft what I can say.", bundle: .module),
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
