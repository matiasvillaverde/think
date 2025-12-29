# AudioGenerator Package Makefile
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
DESTINATION ?= platform=macOS,arch=arm64
ONLY_TESTING ?=
ONLY_TESTING_FLAG := $(if $(ONLY_TESTING),-only-testing:$(ONLY_TESTING),)
SWIFT_BUILD_FLAGS = --configuration $(CONFIGURATION)
SWIFT_TEST_FLAGS = --configuration $(CONFIGURATION)
XCODEBUILD_SETTINGS = SWIFT_SUPPRESS_WARNINGS=NO
XCODEBUILD_TEST_FLAGS = -parallel-testing-enabled NO -parallel-testing-worker-count 1

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
	@echo "$(BLUE)Building AudioGenerator ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors
	@echo "$(BLUE)Building AudioGenerator with strict warnings...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

# MARK: - Test Targets

test: build test-macos ## Run unit tests on macOS (default)

test-macos: ## Run tests on macOS
	@echo "🧪 Testing AudioGenerator..."
	@set -o pipefail; \
	cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) $(XCODEBUILD_TEST_FLAGS) \
		-workspace Think.xcworkspace \
		-scheme AudioGenerator \
		-destination '$(DESTINATION)' \
		$(ONLY_TESTING_FLAG) \
		2>&1 | tee /tmp/test_output.log; \
	TEST_EXIT_CODE=$$?; \
	if [ $$TEST_EXIT_CODE -eq 0 ]; then \
		echo "$(GREEN)✅ AudioGenerator: All tests passed$(NC)"; \
		rm -f /tmp/test_output.log; \
	else \
		echo "$(RED)❌ AudioGenerator: Tests failed$(NC)"; \
		echo "$(RED)Failed test details above ☝️$(NC)"; \
		rm -f /tmp/test_output.log; \
		exit 1; \
	fi

test-ios: ## Run tests for iOS platform
	@echo "$(BLUE)Running AudioGenerator tests on iOS...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme AudioGenerator \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		| xcbeautify || true
	@echo "$(GREEN)✓ iOS tests complete$(NC)"

test-all-platforms: test test-ios ## Run tests on all platforms

test-filter: ## Run tests with filter (usage: make test-filter FILTER=AudioEngineTests)
	@echo "$(BLUE)Running filtered tests: $(FILTER)...$(NC)"
	@swift test $(SWIFT_TEST_FLAGS) --filter $(FILTER)
	@echo "$(GREEN)✓ Filtered tests complete$(NC)"

# MARK: - Quality Targets

lint: ## Run SwiftLint validation
	@echo "$(BLUE)Running SwiftLint on AudioGenerator...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ AudioGenerator linted successfully$(NC)"; \
		else \
			echo "$(RED)❌ AudioGenerator linting failed with violations$(NC)"; \
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
	@echo "$(BLUE)Checking for dead code in AudioGenerator...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes AudioGenerator \
			--targets AudioGenerator \
			--format csv \
			--index-store-path .build/debug/index/store || true; \
		echo "$(GREEN)✓ Dead code analysis complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Periphery not installed$(NC)"; \
		echo "$(YELLOW)  Install with: brew install peripheryapp/periphery/periphery$(NC)"; \
		echo "$(YELLOW)  Using basic unused code detection instead...$(NC)"; \
		echo ""; \
		echo "$(BLUE)Checking for potentially unused code patterns...$(NC)"; \
		grep -r "private.*func\|private.*var\|private.*let" Sources/ | grep -v "test" | head -20 || true; \
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
		echo "$(YELLOW)  Using SwiftLint duplication detection instead...$(NC)"; \
		swiftlint analyze --compiler-log-path .build/debug/*.json Sources/ 2>/dev/null || \
		echo "$(YELLOW)  SwiftLint analyze requires a successful build first$(NC)"; \
	fi

quality: lint deadcode duplication ## Run all code quality checks

# MARK: - Clean Target

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning AudioGenerator build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

# MARK: - Development Helpers

watch-test: ## Watch for changes and re-run tests
	@echo "$(BLUE)Watching for changes...$(NC)"
	@fswatch -o Sources Tests | xargs -n1 -I{} $(MAKE) test

# MARK: - Help

help: ## Show this help message
	@echo "AudioGenerator Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  $(BLUE)CONFIGURATION$(NC)      Build configuration (debug/release, default: debug)"
	@echo "  $(BLUE)FILTER$(NC)             Test filter pattern (for test-filter target)"
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Run tests on macOS (MLX requires xcodebuild)"
	@echo "  make test-ios          # Run tests on iOS simulator"
	@echo "  make lint              # Check code style with strict enforcement"
	@echo "  make quality           # Run all quality checks"
	@echo "  make build-ci          # Build with warnings as errors"
	@echo ""
	@echo "Note: AudioGenerator tests require xcodebuild due to MLX framework dependencies"

.PHONY: build build-ci test test-macos test-ios test-all-platforms test-filter lint lint-fix deadcode duplication quality clean watch-test help
