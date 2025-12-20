# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Think Tools** - A Swift package module within the larger Think AI assistant ecosystem that provides tool implementations for AI model function calling.

### Module Purpose
This module implements function calling capabilities that AI models can use to interact with external systems and services. It's part of the larger Think multi-platform AI application for iOS, macOS, and visionOS.

### Key Dependencies
- **SwiftSoup**: HTML parsing and web content extraction
- **Database**: For persistence and data management
- **Abstractions**: Core protocol definitions and interfaces

## Development Commands

### Testing
```bash
# Run all tests
make test

# Run specific test
make test-filter FILTER=TestName

# Run quality checks (lint + build + test)
make quality
```

### Building
```bash
# Build the module
make build

# Clean build artifacts
make clean
```

### Code Quality
```bash
# Run SwiftLint (must pass with zero violations)
make lint

# Auto-fix linting issues
make lint-fix

# Find dead code
make deadcode
```

## Architecture Patterns

### Tool Implementation Pattern
Tools in this module follow a specific pattern:
1. Implement the `ToolProtocol` from Abstractions
2. Define input/output structures
3. Handle HTML parsing using SwiftSoup where needed
4. Integrate with Database for persistence

### Testing Approach
- Use **SwiftTesting** framework (NOT XCTest)
- Test attributes: `@Test`, `@Suite`
- Mock external dependencies
- Focus on unit testing tool logic

## Module Integration

This module is consumed by:
- **AgentOrchestrator**: For AI model tool calling
- **ContextBuilder**: For formatting tool responses

It depends on:
- **Abstractions**: Protocol definitions
- **Database**: Data persistence
- **SwiftSoup**: HTML parsing

## SwiftLint Configuration

This module follows the project's strict SwiftLint rules:
- No force unwrapping
- No force casting
- Max 100 character line length (warning), 120 (error)
- All public APIs must be documented
- Run `make lint` before every commit

## Development Workflow

1. **Adding a New Tool**:
   - Define the tool protocol in Abstractions if needed
   - Implement the tool in this module
   - Write tests using SwiftTesting
   - Ensure `make quality` passes
   - Wire the tool in AgentOrchestrator

2. **Modifying Existing Tools**:
   - Write failing test first (TDD)
   - Make changes
   - Run `make test` to verify
   - Run `make lint` to check code quality
   - Commit with Conventional Commits format

## Important Notes

- This module uses standard `swift test` (no special Metal requirements)
- All tools must be thread-safe (use actors if needed)
- HTML parsing should handle malformed content gracefully
- Tool responses should include proper error handling