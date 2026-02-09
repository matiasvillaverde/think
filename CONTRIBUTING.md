# Contributing to Think AI

Thank you for your interest in contributing to Think AI! This guide covers the essentials for contributing to our multi-platform AI assistant.

## Code of Conduct

By participating in this project, you agree to follow `CODE_OF_CONDUCT.md`.

## Getting Started

1. Fork and clone the repository
2. Run `make setup`

For detailed setup and CI/CD workflows, see [CI.md](CI.md).

## Development Process

We follow Test-Driven Development (TDD):

1. Write tests first using **SwiftTesting framework** (NOT XCTest)
2. Implement minimal code to pass tests
3. Refactor while keeping tests green
4. Run `make lint`, then `make build`, then `make test` before committing

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning:

```
<type>[optional scope]: <description>
```

### Types
- `feat`: New features → MINOR bump
- `fix`: Bug fixes → PATCH bump
- `feat!` or `BREAKING CHANGE`: Breaking changes → MAJOR bump

### Examples
```bash
feat: add document search with RAG support
fix(auth): handle expired tokens correctly
feat!: migrate to SwiftData 2.0
```

## Code Style

- We run SwiftLint with the strictest possible configuration
- Localize all user-facing strings:
  ```swift
  String(localized: "key", comment: "description", bundle: .module)
  ```

## Pull Request Process

1. Create feature branch: `git checkout -b feat/your-feature`
2. Follow TDD practices
3. Validate locally: `make review-pr PR=your-pr-number`
4. Commit with conventional format
5. Create PR with:
   - Clear description
   - Linked issues
   - Screenshots for UI changes

## Testing Guidelines

- Use SwiftTesting framework exclusively
- Write descriptive test names
- Mock external dependencies
- Keep tests fast and isolated

## Module Development

When creating new modules:
1. Use existing modules as templates
2. Include standard Makefile
3. Configure SwiftLint
4. Update root Makefile's MODULES list
5. Wire dependencies in Factories module

## Getting Help

- Check existing issues and discussions
- Review architecture documentation
- Ask questions in pull requests

Thank you for contributing!
