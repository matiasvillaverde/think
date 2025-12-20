# Makefile for DataAssets module

.PHONY: all clean build test lint lint-fix help

# Default target
all: lint build test

# Help target
help:
	@echo "Available targets:"
	@echo "  make build       - Build the module"
	@echo "  make test        - Run tests"
	@echo "  make lint        - Run SwiftLint"
	@echo "  make lint-fix    - Auto-fix SwiftLint issues"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make all         - Run lint, build, and test"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning DataAssets..."
	@swift package clean
	@rm -rf .build

# Build the module
build: lint
	@echo "$(COLOR_BLUE)Building DataAssets (debug)...$(COLOR_RESET)"
	@swift build
	@echo "$(COLOR_GREEN)✓ Build complete$(COLOR_RESET)"

# Run tests
test: lint build
	@echo "🧪 Testing DataAssets..."
	@swift test

# Lint the code
lint:
	@echo "$(COLOR_BLUE)Running SwiftLint on DataAssets...$(COLOR_RESET)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet --config .swiftlint.yml Sources/ Tests/; then \
			echo "$(COLOR_GREEN)✅ DataAssets linted successfully$(COLOR_RESET)"; \
		else \
			echo "$(COLOR_RED)❌ DataAssets linting failed with violations$(COLOR_RESET)"; \
			exit 1; \
		fi; \
	else \
		echo "$(COLOR_YELLOW)⚠️  SwiftLint not installed. Skipping linting.$(COLOR_RESET)"; \
	fi

# Auto-fix linting issues
lint-fix:
	@echo "🔧 Auto-fixing SwiftLint issues in DataAssets..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --fix --config .swiftlint.yml && swiftlint lint --config .swiftlint.yml; \
	else \
		echo "$(COLOR_YELLOW)⚠️  SwiftLint not installed. Cannot fix.$(COLOR_RESET)"; \
	fi

# Color definitions for output
COLOR_BLUE := \033[0;34m
COLOR_GREEN := \033[0;32m
COLOR_YELLOW := \033[0;33m
COLOR_RED := \033[0;31m
COLOR_RESET := \033[0m