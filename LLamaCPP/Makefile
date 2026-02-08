# LLamaCPP Package Makefile
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
SWIFT_TEST_FLAGS = --configuration $(CONFIGURATION) --parallel --num-workers 1

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
	@echo "$(BLUE)Building LLamaCPP ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors
	@echo "$(BLUE)Building LLamaCPP with strict warnings...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

# MARK: - Test Targets

test: build ## Run unit tests
	@echo "🧪 Testing LLamaCPP..."
	@if [ -n "$$LLAMACPP_TEST_MODEL_PATH" ] && [ -f "$$LLAMACPP_TEST_MODEL_PATH" ]; then \
		echo "$(BLUE)Using LLAMACPP_TEST_MODEL_PATH=$$LLAMACPP_TEST_MODEL_PATH$(NC)"; \
		LLAMA_CPP_FORCE_CPU=1 LLAMA_CPP_TEST_SHARED_MODEL=1 swift test $(SWIFT_TEST_FLAGS); \
	elif ls Tests/LLamaCPPTests/Resources/*.gguf >/dev/null 2>&1; then \
		echo "$(BLUE)Using local GGUF model(s) in Tests/LLamaCPPTests/Resources/$(NC)"; \
		LLAMA_CPP_FORCE_CPU=1 LLAMA_CPP_TEST_SHARED_MODEL=1 swift test $(SWIFT_TEST_FLAGS); \
	else \
		echo "$(YELLOW)No GGUF model found; skipping model-backed tests (LlamaCPPModelTestSuite).$(NC)"; \
		echo "$(YELLOW)Set LLAMACPP_TEST_MODEL_PATH or run: bash Tests/LLamaCPPTests/Resources/download.sh$(NC)"; \
		LLAMA_CPP_FORCE_CPU=1 LLAMA_CPP_TEST_SHARED_MODEL=1 swift test $(SWIFT_TEST_FLAGS) --skip "LlamaCPPModelTestSuite"; \
	fi

test-with-model: build ## Run model-backed tests (requires GGUF model)
	@if [ -n "$$LLAMACPP_TEST_MODEL_PATH" ] && [ -f "$$LLAMACPP_TEST_MODEL_PATH" ]; then \
		echo "$(BLUE)Using LLAMACPP_TEST_MODEL_PATH=$$LLAMACPP_TEST_MODEL_PATH$(NC)"; \
		LLAMA_CPP_FORCE_CPU=1 LLAMA_CPP_TEST_SHARED_MODEL=1 swift test $(SWIFT_TEST_FLAGS); \
	elif ls Tests/LLamaCPPTests/Resources/*.gguf >/dev/null 2>&1; then \
		echo "$(BLUE)Using local GGUF model(s) in Tests/LLamaCPPTests/Resources/$(NC)"; \
		LLAMA_CPP_FORCE_CPU=1 LLAMA_CPP_TEST_SHARED_MODEL=1 swift test $(SWIFT_TEST_FLAGS); \
	else \
		echo "$(RED)✗ No GGUF model available for model-backed tests$(NC)"; \
		echo "$(RED)  Set LLAMACPP_TEST_MODEL_PATH or run: bash Tests/LLamaCPPTests/Resources/download.sh$(NC)"; \
		exit 1; \
	fi

# MARK: - Quality Targets

lint: ## Run SwiftLint validation
	@echo "$(BLUE)Running SwiftLint on LLamaCPP...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ LLamaCPP linted successfully$(NC)"; \
		else \
			echo "$(RED)❌ LLamaCPP linting failed with violations$(NC)"; \
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
	@echo "$(BLUE)Checking for dead code in LLamaCPP...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes LLamaCPP \
			--targets LLamaCPP \
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

# MARK: - Clean Targets

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning LLamaCPP build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

# MARK: - Platform-Specific Targets

test-ios: ## Run tests for iOS platform
	@echo "$(BLUE)Running tests for iOS...$(NC)"
	@xcodebuild test \
		-scheme LLamaCPP \
		-destination "platform=iOS Simulator,name=iPhone 15" \
		-quiet | xcbeautify --is-ci
	@echo "$(GREEN)✓ iOS tests complete$(NC)"

test-all-platforms: test test-ios ## Run tests on all platforms

# MARK: - Development Helpers

watch-test: ## Watch for changes and re-run tests
	@echo "$(BLUE)Watching for changes...$(NC)"
	@fswatch -o Sources Tests | xargs -n1 -I{} $(MAKE) test

# MARK: - Documentation

help: ## Show this help message
	@echo "LLamaCPP Makefile"
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
.PHONY: build build-ci test lint lint-fix deadcode duplication quality clean test-ios test-all-platforms watch-test help

# Suppress make's built-in rules
.SUFFIXES:
