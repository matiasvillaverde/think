# Tools Module Makefile

.PHONY: all clean build test lint lint-fix

# Default target
all: lint build test

# Clean build artifacts
clean:
	@echo "🧹 Cleaning Tools..."
	@swift package clean
	@rm -rf .build

# Build the module
build:
	@echo "🔨 Building Tools..."
	@swift build

# Run tests
test:
	@echo "🧪 Testing Tools..."
	@swift test

# Run SwiftLint
lint:
	@echo "🔍 Linting Tools..."
	@if [ -f .swiftlint.yml ]; then \
		swiftlint lint --strict; \
	else \
		swiftlint lint --strict --config ../.swiftlint.yml; \
	fi

# Auto-fix SwiftLint issues
lint-fix:
	@echo "🔧 Auto-fixing SwiftLint issues..."
	@if [ -f .swiftlint.yml ]; then \
		swiftlint lint --fix; \
	else \
		swiftlint lint --fix --config ../.swiftlint.yml; \
	fi