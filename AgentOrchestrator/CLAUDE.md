# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

AgentOrchestrator is the core module that coordinates AI model inference across different backends (MLXSession, LLamaCPP, ImageGenerator). It implements an agentic loop pattern for handling tool execution and manages the complete generation lifecycle.

## Development Commands

### Build and Test
```bash
# Build the module
make build                          # Build with linting
make build-ci                       # Build with warnings as errors

# Run tests
make test                           # Run all unit tests
swift test --filter TestName        # Run specific test by name
swift test --filter SuiteName       # Run test suite
swift test --filter Module.Suite    # Run specific suite

# Code quality
make lint                           # Check SwiftLint violations
make lint-fix                       # Auto-fix violations
make quality                        # Run lint + deadcode + duplication checks
```

### Test Organization
Tests use SwiftTesting framework (NOT XCTest):
- `@Test` for individual tests
- `@Suite` for test groups
- `.tags(.acceptance)` for integration tests
- Test helpers in `Tests/AgentOrchestratorTests/Utilities/`

## Architecture & Core Components

### Agentic Loop Pattern
The orchestrator implements a loop that:
1. Streams generation from LLM with real-time updates
2. Makes decisions after stream completes (tool execution, completion, continue)
3. Executes tools if requested and rebuilds context with results
4. Continues generation with tool results until complete

Key files:
- `Sources/AgentOrchestrator/AgentOrchestrator.swift`: Main orchestration logic
- `Sources/AgentOrchestrator/Chain/`: Decision chain and state management
- `Sources/AgentOrchestrator/ModelStateCoordinator.swift`: Backend coordination

### State Management
`GenerationState` tracks the complete generation lifecycle:
- Current output and metrics
- Pending tool calls and results
- Iteration count for loop control
- Completion status

### Tool Integration
Tools are executed through the `Tooling` protocol:
- Tool requests parsed from model output via ContextBuilder
- Parallel execution of multiple tools
- Error handling with fallback responses
- Results injected back into context for next iteration

## Critical Patterns

### Thread Safety with Actors
All major components use Swift actors:
```swift
internal final actor AgentOrchestrator: AgentOrchestrating
internal final actor ModelStateCoordinator
```

### Streaming with Throttling
Output updates are throttled to prevent UI overload:
```swift
// Configured via AgentOrchestratorConfiguration
throttleInterval: Duration.milliseconds(100)
```

### Decision Chain Pattern
Decisions are made through a chain of handlers:
```swift
ToolCallHandler → CompletionHandler → ErrorHandler
```

### Database Command Pattern
All database operations use commands:
```swift
try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
```

## Testing Requirements

### Test Structure
- Use `TestEnvironment` struct for complex test setup
- Create helper methods for response configuration
- Use `MockLLMSession` for simulating model responses
- Real components (Database, ContextBuilder) in acceptance tests

### Mock Response Patterns
```swift
// Tool call response format
"<|channel|>tool<|message|>{\"name\": \"calculator\", ...}<|recipient|>calculator<|call|>"

// Final response format
"<|channel|>final<|message|>The result is 42<|end|>"
```

### Test Data Builders
Use helper methods in `AgenticLoopTestHelpers`:
- `createToolCallResponse()`
- `createMultipleToolCallResponse()`
- `createFinalResponse()`

## SwiftLint Configuration

Module uses strict linting with opt-in rules:
- Line length: warning at 110, error at 120
- Function body: max 30 lines (slightly relaxed for tests)
- Cyclomatic complexity: max 8
- File length exceptions via `// swiftlint:disable file_length`

## Development Workflow

### Adding New Features
1. Write failing test using SwiftTesting
2. Implement in appropriate component (orchestrator, coordinator, chain)
3. Run `make test` to verify
4. Run `make lint` and fix violations
5. Update integration tests if needed

### Debugging Agentic Loops
Enable verbose logging:
```swift
Logger(subsystem: "AgentOrchestrator", category: "tokenProcessing")
```

Key log points:
- Orchestration loop iterations
- Decision making
- Tool execution
- Context rebuilding

### Performance Considerations
- Stream processing uses `AsyncThrowingStream`
- Tool execution is concurrent when possible
- Context building cached between iterations
- Metrics tracked via `ChunkMetrics`

## Module Dependencies

Direct dependencies:
- `Abstractions`: Protocol definitions
- `Database`: Persistence layer
- `ContextBuilder`: Prompt formatting and output parsing
- `Tools`: Tool execution
- `ImageGenerator`: Stable Diffusion
- `LLamaCPP`: CPU/GPU inference
- `MLXSession`: MLX framework
- `ModelDownloader`: HuggingFace integration

## Common Issues & Solutions

### Issue: Tests fail with "noChatLoaded"
**Solution**: Ensure `orchestrator.load(chatId:)` called before generation

### Issue: Tool results not appearing in context
**Solution**: Check `ContextBuilder` formatter supports tool responses for model

### Issue: Infinite tool execution loops
**Solution**: Verify decision chain has proper completion conditions

### Issue: Memory growth during streaming
**Solution**: Check throttling is enabled and partial updates are released