# RemoteSession Package Makefile
# Self-contained Makefile for autonomous package development
#
# Usage:
#   make build              - Build the package
#   make test              - Run unit tests
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
	@echo "$(BLUE)Building RemoteSession ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors
	@echo "$(BLUE)Building RemoteSession with strict warnings...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

# MARK: - Test Targets

test: build ## Run unit tests (excludes integration tests)
	@echo "🧪 Testing RemoteSession..."
	@swift test $(SWIFT_TEST_FLAGS) --skip "Integration"

test-integration: build ## Run integration tests (requires API keys)
	@echo "🧪 Running integration tests..."
	@if [ -f .env ]; then \
		echo "$(BLUE)Loading API keys from .env$(NC)"; \
		export $$(cat .env | xargs) && swift test $(SWIFT_TEST_FLAGS) --filter "Integration"; \
	elif [ -n "$$OPENROUTER_API_KEY" ]; then \
		swift test $(SWIFT_TEST_FLAGS) --filter "Integration"; \
	else \
		echo "$(YELLOW)⚠️  Requires OPENROUTER_API_KEY in .env or environment$(NC)"; \
		swift test $(SWIFT_TEST_FLAGS) --filter "Integration"; \
	fi

# MARK: - Quality Targets

lint: ## Run SwiftLint validation
	@echo "$(BLUE)Running SwiftLint on RemoteSession...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ RemoteSession linted successfully$(NC)"; \
		else \
			echo "$(RED)❌ RemoteSession linting failed with violations$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

lint-fix: ## Auto-fix SwiftLint issues
	@echo "$(BLUE)Auto-fixing SwiftLint issues...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --fix Sources/ Tests/; \
		echo "$(GREEN)✓ Auto-fix complete$(NC)"; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

# MARK: - Code Quality Targets

deadcode: ## Find dead code using periphery
	@echo "$(BLUE)Checking for dead code in RemoteSession...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes RemoteSession \
			--targets RemoteSession \
			--format csv \
			--index-store-path .build/debug/index/store || true; \
		echo "$(GREEN)✓ Dead code analysis complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Periphery not installed$(NC)"; \
		echo "$(YELLOW)  Install with: brew install peripheryapp/periphery/periphery$(NC)"; \
	fi

duplication: ## Find duplicated code
	@echo "$(BLUE)Checking for code duplication...$(NC)"
	@if command -v jscpd >/dev/null 2>&1; then \
		jscpd Sources/ \
			--min-lines 5 \
			--min-tokens 50 \
			--reporters "console" \
			--format "swift" || true; \
		echo "$(GREEN)✓ Duplication analysis complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠ jscpd not installed$(NC)"; \
		echo "$(YELLOW)  Install with: npm install -g jscpd$(NC)"; \
	fi

quality: lint deadcode duplication ## Run all code quality checks

# MARK: - Clean Targets

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning RemoteSession build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

# MARK: - Documentation

help: ## Show this help message
	@echo "RemoteSession Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables:"
	@echo "  $(BLUE)CONFIGURATION$(NC)      Build configuration (debug/release) [default: debug]"
	@echo "  $(BLUE)PLATFORM$(NC)           Target platform [default: macos]"
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Run tests"
	@echo "  make lint              # Check code style"
	@echo "  make build CONFIGURATION=release  # Build release configuration"

# Mark all targets as phony (not files)
.PHONY: build build-ci test test-integration lint lint-fix deadcode duplication quality clean help

# Suppress make's built-in rules
.SUFFIXES:
