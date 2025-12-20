# ContextBuilder Package Makefile
# Self-contained Makefile for autonomous package development
#
# Usage:
#   make build              - Build the package
#   make test              - Run fast unit tests
#   make lint              - Run SwiftLint checks
#   make clean             - Clean build artifacts
#   make help              - Show this help message

# Configuration
CONFIGURATION ?= debug
PLATFORM ?= macos
SWIFT_BUILD_FLAGS = --configuration $(CONFIGURATION)
SWIFT_TEST_FLAGS = --configuration $(CONFIGURATION) --parallel

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
RED = \033[0;31m
NC = \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# MARK: - Build Targets

build: lint ## Build the package
	@echo "$(BLUE)Building ContextBuilder ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors (for CI)
	@echo "$(BLUE)Building ContextBuilder with warnings as errors...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ Build complete (warnings as errors)$(NC)"

# MARK: - Test Targets

test: build ## Run unit tests
	@echo "🧪 Testing ContextBuilder..."
	@swift test $(SWIFT_TEST_FLAGS)

test-all: test ## Run all tests (currently same as test)

# MARK: - Quality Targets

lint: ## Run SwiftLint validation
	@echo "$(BLUE)Running SwiftLint on ContextBuilder...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if [ -f .swiftlint.yml ]; then \
			if swiftlint lint --strict --quiet; then \
				echo "$(GREEN)✅ ContextBuilder linted successfully$(NC)"; \
			else \
				echo "$(RED)❌ ContextBuilder linting failed with violations$(NC)"; \
				exit 1; \
			fi; \
		else \
			if swiftlint lint --strict --quiet Sources/ Tests/; then \
				echo "$(GREEN)✅ ContextBuilder linted successfully$(NC)"; \
			else \
				echo "$(RED)❌ ContextBuilder linting failed with violations$(NC)"; \
				exit 1; \
			fi; \
		fi; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

lint-fix: ## Auto-fix SwiftLint violations where possible
	@echo "$(BLUE)Auto-fixing SwiftLint violations in ContextBuilder...$(NC)"
	@if which swiftlint >/dev/null; then \
		if [ -f .swiftlint.yml ]; then \
			swiftlint lint --fix --quiet || true; \
		else \
			swiftlint lint --fix --quiet --path Sources --path Tests || true; \
		fi; \
		echo "$(GREEN)✓ Auto-fix complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  SwiftLint not installed$(NC)"; \
	fi

# MARK: - Utility Targets

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning ContextBuilder build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

help: ## Show this help message
	@echo "ContextBuilder Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: build build-ci test test-all lint lint-fix clean help
