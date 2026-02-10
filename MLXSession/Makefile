# MLXSession Package Makefile
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
XCODEBUILD_SETTINGS = SWIFT_SUPPRESS_WARNINGS=NO

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
RED = \033[0;31m
NC = \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# MARK: - Build Targets

build: ## Build the package
	@echo "$(BLUE)Building MLXSession ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors
	@echo "$(BLUE)Building MLXSession with strict warnings...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

# MARK: - Test Targets
# Note: Using xcodebuild with workspace instead of swift test because MLX requires Metal framework
# IMPORTANT: Tests must run SERIALLY (not in parallel) because they share GPU resources

test: build test-macos ## Run tests using xcodebuild with workspace (required for MLX Metal support)

test-macos: ## Run tests on macOS with proper Metal support (SERIAL execution for GPU safety)
	@echo "🧪 Testing MLXSession..."
	@echo "$(YELLOW)⚠️  Tests run serially to avoid GPU conflicts$(NC)"
	@set -o pipefail; \
	cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) -quiet \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | xcbeautify --is-ci | tee /tmp/test_output.log; \
	TEST_EXIT_CODE=$$?; \
	if [ $$TEST_EXIT_CODE -eq 0 ]; then \
		echo "$(GREEN)✅ MLXSession: All tests passed$(NC)"; \
		rm -f /tmp/test_output.log; \
	else \
		echo "$(RED)❌ MLXSession: Tests failed$(NC)"; \
		echo "$(RED)Failed test details above ☝️$(NC)"; \
		rm -f /tmp/test_output.log; \
		exit 1; \
	fi
	@rm -f /tmp/test_output.log

test-verbose: ## Run tests with verbose output (SERIAL execution)
	@echo "🧪 Testing MLXSession (verbose)..."
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | xcbeautify

test-acceptance: ## Run acceptance tests for all architectures (SERIAL execution for GPU safety)
	@echo "$(YELLOW)⚠️  Running acceptance tests with real models...$(NC)"
	@echo "$(BLUE)This will test all available model architectures$(NC)"
	@echo "$(YELLOW)⚠️  Tests run sequentially to prevent GPU conflicts$(NC)"
	@$(MAKE) test-all-architectures
	@echo "$(GREEN)✓ All acceptance tests complete$(NC)"

# MARK: - Architecture-Specific Test Targets
# IMPORTANT: All tests run with parallel-testing-enabled NO to prevent GPU conflicts
# Only one model can use GPU/Metal at a time

test-llama: ## Test Llama architecture models (GPU-safe serial execution)
	@echo "$(BLUE)Testing Llama models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXLlamaTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-mistral: ## Test Mistral architecture models
	@echo "$(BLUE)Testing Mistral models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXMistralTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-phi: ## Test Phi architecture models
	@echo "$(BLUE)Testing Phi models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXPhiTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-phi3: ## Test Phi3 architecture models
	@echo "$(BLUE)Testing Phi3 models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXPhi3Tests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-phimoe: ## Test PhiMoE architecture models
	@echo "$(BLUE)Testing PhiMoE models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXPhiMoETests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-gemma: ## Test Gemma architecture models
	@echo "$(BLUE)Testing Gemma models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXGemmaTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-gemma2: ## Test Gemma2 architecture models
	@echo "$(BLUE)Testing Gemma2 models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXGemma2Tests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-qwen: ## Test Qwen architecture models
	@echo "$(BLUE)Testing Qwen models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXQwenTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-starcoder: ## Test Starcoder architecture models
	@echo "$(BLUE)Testing Starcoder models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXStarcoderTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-cohere: ## Test Cohere architecture models
	@echo "$(BLUE)Testing Cohere models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXCohereTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-openelm: ## Test OpenELM architecture models
	@echo "$(BLUE)Testing OpenELM models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXOpenELMTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-internlm: ## Test InternLM architecture models
	@echo "$(BLUE)Testing InternLM models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXInternLMTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-deepseek: ## Test Deepseek architecture models
	@echo "$(BLUE)Testing Deepseek models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXDeepseekTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-granite: ## Test Granite architecture models
	@echo "$(BLUE)Testing Granite models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXGraniteTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-bitnet: ## Test Bitnet architecture models
	@echo "$(BLUE)Testing Bitnet models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXBitnetTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-smollm: ## Test SmolLM architecture models
	@echo "$(BLUE)Testing SmolLM models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXSmolLMTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-ernie: ## Test ERNIE architecture models
	@echo "$(BLUE)Testing ERNIE models...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXErnieTests \
		-parallel-testing-enabled NO \
		-maximum-concurrent-test-simulator-destinations 1 \
		2>&1 | tee /tmp/test_output.log | xcbeautify --is-ci || true

test-all-architectures: ## Run tests for all architectures (SEQUENTIALLY to avoid GPU conflicts)
	@echo "$(BLUE)Testing all model architectures...$(NC)"
	@echo "$(YELLOW)⚠️  Running tests sequentially to avoid GPU resource conflicts$(NC)"
	@echo "$(YELLOW)This will take time as each architecture runs one at a time$(NC)"
	@for arch in llama mistral phi phi3 phimoe gemma gemma2 qwen starcoder cohere openelm internlm deepseek granite bitnet smollm ernie; do \
		echo "$(YELLOW)Testing $$arch architecture...$(NC)"; \
		$(MAKE) test-$$arch || echo "$(YELLOW)⚠ $$arch tests failed or skipped$(NC)"; \
		echo "$(GREEN)✓ $$arch complete, moving to next...$(NC)"; \
	done
	@echo "$(GREEN)✓ All architecture tests complete (run serially)$(NC)"

test-filter: ## Run tests with filter (usage: make test-filter FILTER=BasicTest)
	@if [ -z "$(FILTER)" ]; then \
		echo "$(RED)Error: FILTER not specified. Usage: make test-filter FILTER=testName$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running filtered tests: $(FILTER)...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme MLXSession \
		-destination 'platform=macOS' \
		-only-testing:MLXSessionTests/$(FILTER) \
		| xcbeautify --is-ci
	@echo "$(GREEN)✓ Filtered tests complete$(NC)"

# MARK: - Quality Targets

lint: ## Run SwiftLint validation
	@echo "$(BLUE)Running SwiftLint on MLXSession...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ MLXSession linted successfully$(NC)"; \
		else \
			echo "$(RED)❌ MLXSession linting failed with violations$(NC)"; \
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
	@echo "$(BLUE)Checking for dead code in MLXSession...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes MLXSession \
			--targets MLXSession \
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
	@echo "$(BLUE)Cleaning MLXSession build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

# MARK: - Platform-Specific Targets

test-ios: ## Run tests for iOS platform
	@echo "$(BLUE)Running tests for iOS...$(NC)"
	@xcodebuild test $(XCODEBUILD_SETTINGS) \
		-scheme MLXSession \
		-destination "platform=iOS Simulator,name=iPhone 15" \
		-quiet | xcbeautify --is-ci
	@echo "$(GREEN)✓ iOS tests complete$(NC)"

test-all-platforms: test test-ios ## Run tests on all platforms

# MARK: - Model Management

download-models: ## Download all models sequentially (~20-30GB)
	@bash download-all-models.sh

models-size: ## Show disk usage of downloaded models
	@echo "$(BLUE)Model disk usage:$(NC)"
	@du -sh Tests/*/Resources/*/ 2>/dev/null | sort -hr || echo "No models downloaded yet"

models-clean: ## Remove all downloaded models (WARNING: requires re-download)
	@echo "$(YELLOW)Warning: This will delete all downloaded models$(NC)"
	@echo -n "Continue? (y/N): "; \
	read response && [ "$$response" = "y" ] && \
		find Tests -name "*.safetensors*" -delete && \
		find Tests -name "config.json" -path "*/Resources/*" -delete && \
		find Tests -name "tokenizer*.json" -path "*/Resources/*" -delete && \
		find Tests -name "*.model" -path "*/Resources/*" -delete && \
		echo "$(GREEN)✓ Models cleaned$(NC)" || echo "Cancelled"

models-list: ## List all available models and their download status
	@echo "$(BLUE)Model download status:$(NC)"
	@for script in Tests/*/Resources/*/download.sh Tests/*/Resources/download.sh; do \
		if [ -f "$$script" ]; then \
			dir=$$(dirname "$$script"); \
			name=$$(basename "$$dir"); \
			if [ -f "$$dir/model.safetensors" ] || [ -f "$$dir/model.safetensors.index.json" ]; then \
				echo "  $(GREEN)✓$(NC) $$name"; \
			else \
				echo "  $(YELLOW)○$(NC) $$name"; \
			fi; \
		fi; \
	done 2>/dev/null | sort -u

# MARK: - Development Helpers

watch-test: ## Watch for changes and re-run tests
	@echo "$(BLUE)Watching for changes...$(NC)"
	@fswatch -o Sources Tests | xargs -n1 -I{} $(MAKE) test

# MARK: - Documentation

help: ## Show this help message
	@echo "MLXSession Makefile"
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
.PHONY: build build-ci test lint lint-fix deadcode duplication quality clean test-ios test-all-platforms watch-test help \
	test-llama test-mistral test-phi test-phi3 test-phimoe test-gemma test-gemma2 test-qwen \
	test-starcoder test-cohere test-openelm test-internlm test-deepseek test-granite \
	test-bitnet test-smollm test-ernie test-all-architectures

# Suppress make's built-in rules
.SUFFIXES:
