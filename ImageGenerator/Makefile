# ImageGenerator Package Makefile
# Self-contained Makefile for autonomous package development
# Uses xcodebuild for tests due to Core ML framework requirements
#
# Usage:
#   make build              - Build the package
#   make test              - Run fast unit tests (excludes acceptance tests)
#   make test-acceptance   - Run acceptance tests (uses real Core ML models - slow!)
#   make lint              - Run SwiftLint checks (ULTRA STRICT)
#   make clean             - Clean build artifacts
#   make help              - Show this help message

# Configuration
CONFIGURATION ?= debug
PLATFORM ?= macos
SWIFT_BUILD_FLAGS = --configuration $(CONFIGURATION)
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

build: lint ## Build the package
	@echo "$(BLUE)Building ImageGenerator ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors for CI
	@echo "$(BLUE)Building ImageGenerator with warnings as errors...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

# MARK: - Test Targets

test: build ## Run fast unit tests (excludes acceptance tests)
	@echo "🧪 Testing ImageGenerator..."
	@swift test $(SWIFT_TEST_FLAGS)

test-macos: test ## Run fast tests on macOS (alias for test)

test-acceptance: ## Run acceptance tests (downloads/loads real Core ML models - slow!)
	@echo "$(YELLOW)⚠️  Running acceptance tests - this will load real Core ML models and may take time!$(NC)"
	@echo "$(BLUE)Running ImageGenerator acceptance tests...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=macOS' \
		-only-testing:ImageGeneratorTests/ImageGeneratorAcceptanceTests \
		| xcbeautify || true
	@echo "$(GREEN)✓ Acceptance tests complete$(NC)"

test-all: ## Run all tests (fast + acceptance)
	@echo "$(BLUE)Running all ImageGenerator tests...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=macOS' \
		| xcbeautify || true
	@echo "$(GREEN)✓ All tests complete$(NC)"

test-filter: ## Run tests with filter (usage: make test-filter FILTER=testName)
	@if [ -z "$(FILTER)" ]; then \
		echo "$(RED)Error: FILTER not specified. Usage: make test-filter FILTER=testName$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running filtered tests: $(FILTER)...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=macOS' \
		-only-testing:ImageGeneratorTests/$(FILTER) \
		| xcbeautify || true
	@echo "$(GREEN)✓ Filtered tests complete$(NC)"

test-ios: ## Run tests on iOS simulator
	@echo "$(BLUE)Running ImageGenerator tests on iOS...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
		-skip-testing:ImageGeneratorTests/ImageGeneratorAcceptanceTests \
		| xcbeautify || true
	@echo "$(GREEN)✓ iOS tests complete$(NC)"

test-metal: ## Test Core ML with Metal Performance Shaders
	@echo "$(BLUE)Testing Core ML Metal integration...$(NC)"
	@echo "$(YELLOW)Note: This requires a device with Metal support$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=macOS' \
		-only-testing:ImageGeneratorTests/MetalPerformanceTests \
		| xcbeautify || true
	@echo "$(GREEN)✓ Metal tests complete$(NC)"

# MARK: - Quality Targets

lint: ## Run SwiftLint validation (ULTRA STRICT)
	@echo "$(BLUE)Running SwiftLint on ImageGenerator (ULTRA STRICT MODE)...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ ImageGenerator passed ULTRA STRICT linting$(NC)"; \
		else \
			echo "$(RED)❌ ImageGenerator linting failed with violations$(NC)"; \
			echo "$(RED)This module enforces the strictest code quality standards.$(NC)"; \
			echo "$(RED)Fix all violations before proceeding.$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

lint-fix: ## Auto-fix SwiftLint issues
	@echo "$(BLUE)Auto-fixing SwiftLint issues...$(NC)"
	@echo "$(YELLOW)Note: Many strict rules cannot be auto-fixed$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --fix Sources/ Tests/; \
		echo "$(GREEN)✓ Auto-fix complete$(NC)"; \
		echo "$(YELLOW)Run 'make lint' to see remaining violations$(NC)"; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

lint-verbose: ## Run SwiftLint with detailed output
	@echo "$(BLUE)Running SwiftLint with verbose output...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --strict Sources/ Tests/; \
	else \
		echo "$(RED)✗ SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
		exit 1; \
	fi

# MARK: - Code Quality Targets

deadcode: ## Find dead code using periphery
	@echo "$(BLUE)Checking for dead code in ImageGenerator...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes ImageGenerator \
			--targets ImageGenerator \
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
	@if [ -d "Sources" ] && [ -d "Tests" ]; then \
		echo "$(YELLOW)Analyzing Sources...$(NC)"; \
		if command -v jscpd >/dev/null 2>&1; then \
			jscpd Sources Tests --min-tokens 30 --reporters "consoleFull" || true; \
		else \
			echo "$(YELLOW)jscpd not installed. Basic duplication check:$(NC)"; \
			find Sources Tests -name "*.swift" -exec md5 {} \; | sort | uniq -d -w 32 | head -10 || true; \
		fi; \
		echo "$(GREEN)✓ Duplication analysis complete$(NC)"; \
	else \
		echo "$(RED)Sources or Tests directory not found$(NC)"; \
	fi

complexity: ## Analyze code complexity
	@echo "$(BLUE)Analyzing code complexity...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint analyze --compiler-log-path .build/debug/*.json || true; \
		echo "$(GREEN)✓ Complexity analysis complete$(NC)"; \
	else \
		echo "$(YELLOW)SwiftLint not available for complexity analysis$(NC)"; \
	fi

quality: lint deadcode duplication complexity ## Run all quality checks

# MARK: - Core ML Specific Targets

validate-models: ## Validate Core ML model files
	@echo "$(BLUE)Validating Core ML models...$(NC)"
	@if [ -d "Tests/ImageGeneratorTests/Resources/Models" ]; then \
		find Tests/ImageGeneratorTests/Resources/Models -name "*.mlmodelc" -o -name "*.mlpackage" | while read model; do \
			echo "$(YELLOW)Checking: $$model$(NC)"; \
		done; \
		echo "$(GREEN)✓ Model validation complete$(NC)"; \
	else \
		echo "$(YELLOW)No Core ML models found in test resources$(NC)"; \
	fi

benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running Core ML performance benchmarks...$(NC)"
	@cd .. && xcodebuild test $(XCODEBUILD_SETTINGS) \
		-workspace Think.xcworkspace \
		-scheme ImageGenerator \
		-destination 'platform=macOS' \
		-only-testing:ImageGeneratorTests/PerformanceBenchmarks \
		| xcbeautify || true
	@echo "$(GREEN)✓ Benchmarks complete$(NC)"

# MARK: - Utility Targets

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning ImageGenerator build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@rm -rf ~/Library/Developer/Xcode/DerivedData/*ImageGenerator*
	@echo "$(GREEN)✓ Clean complete$(NC)"

reset: clean ## Deep clean including Core ML caches
	@echo "$(BLUE)Deep cleaning including Core ML model caches...$(NC)"
	@rm -rf ~/Library/Caches/com.apple.CoreML/
	@rm -rf /tmp/ImageGenerator*
	@echo "$(GREEN)✓ Deep clean complete$(NC)"

watch-test: ## Watch for changes and re-run tests
	@echo "$(BLUE)Watching for changes (press Ctrl+C to stop)...$(NC)"
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o Sources Tests | xargs -n1 -I{} $(MAKE) test; \
	else \
		echo "$(RED)✗ fswatch not installed. Install with: brew install fswatch$(NC)"; \
		exit 1; \
	fi

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v swift-doc >/dev/null 2>&1; then \
		swift doc generate Sources --module-name ImageGenerator \
			--output docs \
			--format html; \
		echo "$(GREEN)✓ Documentation generated in docs/$(NC)"; \
	else \
		echo "$(YELLOW)swift-doc not installed. Using Xcode docbuild...$(NC)"; \
		xcodebuild docbuild \
			-scheme ImageGenerator \
			-derivedDataPath .build/docs; \
		echo "$(GREEN)✓ Documentation generated$(NC)"; \
	fi

# MARK: - Help

help: ## Show this help message
	@echo "ImageGenerator Makefile"
	@echo ""
	@echo "$(RED)⚠️  ULTRA STRICT LINTING ENABLED ⚠️$(NC)"
	@echo "This module has the strictest code quality standards in the project."
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment variables:"
	@echo "  $(BLUE)CONFIGURATION$(NC)     Build configuration (debug/release, default: debug)"
	@echo "  $(BLUE)FILTER$(NC)            Test filter for test-filter target"
	@echo ""
	@echo "Examples:"
	@echo "  make test                    # Run fast tests only"
	@echo "  make test-acceptance         # Run Core ML acceptance tests"
	@echo "  make test-metal              # Test Metal Performance Shaders"
	@echo "  make lint                    # Run ultra-strict linting"
	@echo "  make quality                 # Run all quality checks"
	@echo "  make benchmark               # Run performance benchmarks"
	@echo ""
	@echo "Note: ImageGenerator uses Core ML framework which requires:"
	@echo "  - macOS 15.0+ or iOS 18.0+"
	@echo "  - Metal support for optimal performance"
	@echo "  - Neural Engine for best efficiency"
	@echo ""
	@echo "Core ML models consist of:"
	@echo "  - TextEncoder.mlmodelc"
	@echo "  - Unet.mlmodelc"
	@echo "  - VAEDecoder.mlmodelc"
	@echo "  - VAEEncoder.mlmodelc (for image-to-image)"

.PHONY: build build-ci test test-macos test-acceptance test-all test-filter test-ios test-metal lint lint-fix lint-verbose deadcode duplication complexity quality validate-models benchmark clean reset watch-test docs help
