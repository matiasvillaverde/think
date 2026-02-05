# ThinkCLI Package Makefile

CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS = --configuration $(CONFIGURATION)
SWIFT_TEST_FLAGS = --configuration $(CONFIGURATION) --parallel

.DEFAULT_GOAL := help

build: lint
	@echo "🔨 Building ThinkCLI..."
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "✅ ThinkCLI build complete"

test: build
	@echo "🧪 Testing ThinkCLI..."
	@swift test $(SWIFT_TEST_FLAGS) --filter ThinkCLITests
	@echo "✅ ThinkCLI tests complete"

run: build
	@echo "🚀 Running ThinkCLI..."
	@swift run $(SWIFT_BUILD_FLAGS) think $(ARGS)

lint:
	@echo "🧹 Linting ThinkCLI..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --strict --quiet --config .swiftlint.yml; \
	else \
		echo "❌ SwiftLint not installed. Install with: brew install swiftlint"; \
		exit 1; \
	fi

lint-fix:
	@echo "🔧 Auto-fixing SwiftLint issues..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --fix --config .swiftlint.yml; \
	else \
		echo "❌ SwiftLint not installed. Install with: brew install swiftlint"; \
		exit 1; \
	fi

clean:
	@echo "🧹 Cleaning ThinkCLI..."
	@swift package clean
	@rm -rf .build

help:
	@echo "ThinkCLI Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make lint        - Run SwiftLint"
	@echo "  make build       - Build ThinkCLI"
	@echo "  make test        - Run ThinkCLI tests"
	@echo "  make run         - Run ThinkCLI (pass ARGS=...)"
	@echo "  make clean       - Clean build artifacts"

.PHONY: build test run lint lint-fix clean help
