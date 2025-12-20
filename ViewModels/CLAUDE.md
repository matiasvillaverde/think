# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Essential Commands
```bash
# Build and validate code (enforces SwiftLint)
make build

# Run all tests using SwiftTesting framework
make test

# Run SwiftLint validation (strict enforcement)
make lint

# Auto-fix linting issues where possible
make lint-fix

# Complete quality check (build + test + lint)
make quality

# Find unused/dead code
make deadcode
```

### Test Execution
```bash
# Run specific test suite
swift test --filter "AppViewModelTests"

# Run single test method
swift test --filter "shouldShowOnboardingWelcomeWhenNoChats"

# Run with verbose output
swift test --verbose
```

## Architecture Overview

### Actor-Based ViewModels
All ViewModels are implemented as `actor` types for thread safety:
```swift
public final actor ChatViewModel: ChatViewModeling {
    // All state is actor-isolated
    // UI updates hop to MainActor when needed
}
```

**Critical Pattern**: ViewModels are actors but hop to `@MainActor` only for database operations:
```swift
try await database.write(ChatCommands.Create(...))  // Runs on MainActor
```

### Database Command Pattern (Mandatory)
ViewModels **NEVER** access database models directly. Always use commands:
```swift
// CORRECT: Use commands
try await database.write(ChatCommands.Create(personality: personality))
try await database.read(MessageCommands.CountMessages(chatId: chatId))

// WRONG: Direct access ❌
database.models...
```

### Error Handling Strategy
Convert technical errors to user notifications instead of throwing to UI:
```swift
private func notify(message: String, type: NotificationType) async {
    try? await database.write(NotificationCommands.Create(type: type, message: message))
}
```

### Protocol-Driven Design
Every ViewModel implements a protocol from `Abstractions` module:
- `AppViewModeling`
- `ChatViewModeling`
- `ModelDownloaderViewModeling`

This enables dependency injection and testing with mocks.

## Testing Framework: SwiftTesting

### Modern Swift Testing (NOT XCTest)
```swift
@Suite("ViewModel Tests")
internal enum ViewModelTests {
    @Test("Should handle user interaction")
    @MainActor  // For UI-related tests
    func shouldHandleUserInteraction() async throws {
        #expect(result == expected)  // NOT XCTAssert
    }
}
```

### Integration Testing Philosophy
- **Real Database**: Use in-memory SwiftData, not mocks
- **Real Commands**: Test actual database command execution
- **Minimal Mocking**: Only mock external dependencies like model downloaders

### Test Structure Pattern
```swift
@Suite("Feature Tests")
struct FeatureTests {
    @Test("Specific behavior")
    @MainActor
    func testSpecificBehavior() async throws {
        // Given: Setup real database
        let database = DatabaseTestHelpers.createInMemoryDatabase()
        
        // When: Execute action through ViewModel
        let viewModel = AppViewModel(database: database)
        await viewModel.performAction()
        
        // Then: Verify database state changes
        let result = try await database.read(SomeCommand())
        #expect(result.isValid)
    }
}
```

## Key Architectural Patterns

### Background Task Management
ViewModels track complex async operations:
```swift
private var downloadTasks: [UUID: Task<Void, Never>] = [:]
private var activeDownloads: Set<UUID> = []

// Tasks are properly cancelled to prevent leaks
task.cancel()
downloadTasks.removeValue(forKey: id)
```

### Progress Throttling
UI updates are throttled for performance:
```swift
private static let progressThrottleMilliseconds: Int = 500
private static let minProgressChangeThreshold: Double = 0.01
```

### Platform-Specific Features
iOS features are cleanly isolated:
```swift
#if os(iOS)
let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
await impactGenerator.impactOccurred()
#endif
```

### Localization Requirement
All user-facing strings MUST use bundle localization:
```swift
String(localized: "Chat deleted", bundle: .module)
```

## SwiftLint Configuration

### Strict Enforcement
- Line length: 130 warning, 150 error
- Type body: 260 warning, 300 error
- "Opt-in all rules" approach with strategic exceptions

### Key Disabled Rules
- `explicit_acl`: Access control not required
- `one_declaration_per_file`: Multiple types per file allowed
- `type_contents_order`: Flexible member ordering

**Always run `make lint` before commits** - violations block builds.

## Non-Obvious Patterns

### Animation Through Database Updates
Welcome messages animate word-by-word by incrementally updating database records:
```swift
for (index, word) in words.enumerated() {
    currentResponse += word
    try await database.write(MessageCommands.UpdateProcessedOutput(...))
    // Creates smooth typing animation
}
```

### Auto-Rename Background Tasks
Chats automatically rename themselves based on content:
```swift
Task(priority: .background) {
    try await database.writeInBackground(ChatCommands.AutoRenameFromContent(chatId: chatId))
}
```

### Download Resumption Architecture
Background downloads can resume across app launches:
```swift
public func resumeBackgroundDownloads() async {
    await _modelDownloaderViewModel.resumeBackgroundDownloads()
}
```

## Development Requirements

### Build Environment
- **Swift 6.0** with strict concurrency
- **Warnings as errors**: `-Xswiftc -warnings-as-errors`
- **Platform minimums**: iOS 18, macOS 15, visionOS 2

### Thread Safety
- All ViewModels MUST be actors
- Database operations MUST use command pattern
- UI updates MUST happen on MainActor

### Testing Requirements
- Use SwiftTesting framework (`@Test`, `#expect`)
- Prefer integration tests with real database
- Mock external dependencies only
- Test both happy path and error conditions

## Performance Considerations

- **Actor isolation** prevents data races but requires `await` management
- **Progress throttling** reduces UI update frequency  
- **Background tasks** for non-critical operations
- **Lazy initialization** of expensive resources
- **Task cancellation** prevents resource leaks

Remember: ViewModels coordinate between UI and business logic while maintaining strict thread safety and clean architecture boundaries.