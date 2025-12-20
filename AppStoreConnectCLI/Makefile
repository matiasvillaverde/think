# AppStoreConnectCLI Package Makefile
# Self-contained Makefile for autonomous package development
#
# Usage:
#   make build              - Build the package
#   make test              - Run unit tests (fast)
#   make test-acceptance   - Run acceptance tests (slow, real API calls)
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
	@echo "$(BLUE)Building AppStoreConnectCLI ($(CONFIGURATION))...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-ci: lint ## Build with warnings as errors (CI mode)
	@echo "$(BLUE)Building AppStoreConnectCLI with warnings as errors...$(NC)"
	@swift build $(SWIFT_BUILD_FLAGS) -Xswiftc -warnings-as-errors
	@echo "$(GREEN)✓ CI build complete$(NC)"

build-release: lint ## Build release version
	@echo "$(BLUE)Building AppStoreConnectCLI (release)...$(NC)"
	@swift build --configuration release
	@echo "$(GREEN)✓ Release build complete$(NC)"

# MARK: - Test Targets

test: build ## Run unit tests (excludes acceptance tests)
	@echo "🧪 Testing AppStoreConnectCLI..."
	@swift test $(SWIFT_TEST_FLAGS) --filter AppStoreConnectCLITests

test-acceptance: ## Run acceptance tests (real API calls - slow!)
	@echo "$(YELLOW)⚠️  Running acceptance tests with real App Store Connect API$(NC)"
	@echo "$(YELLOW)   This may take several minutes and requires valid credentials$(NC)"
	@swift test $(SWIFT_TEST_FLAGS) --filter AcceptanceTests
	@echo "$(GREEN)✓ Acceptance tests complete$(NC)"

test-all: test test-acceptance ## Run all tests (unit + acceptance)

# MARK: - Quality Targets

lint: ## Run SwiftLint validation with strict enforcement
	@echo "$(BLUE)Running SwiftLint on AppStoreConnectCLI...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		if swiftlint lint --strict --quiet Sources/ Tests/; then \
			echo "$(GREEN)✅ AppStoreConnectCLI linted successfully$(NC)"; \
		else \
			echo "$(RED)❌ AppStoreConnectCLI linting failed with violations$(NC)"; \
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
	@echo "$(BLUE)Checking for dead code in AppStoreConnectCLI...$(NC)"
	@if command -v periphery >/dev/null 2>&1; then \
		periphery scan --project . --schemes AppStoreConnectCLI \
			--targets AppStoreConnectCLI \
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
	@echo "$(BLUE)Cleaning AppStoreConnectCLI build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

# MARK: - Platform-Specific Targets

test-ios: ## Run tests for iOS platform
	@echo "$(BLUE)Running tests for iOS...$(NC)"
	@xcodebuild test \
		-scheme AppStoreConnectCLI \
		-destination "platform=iOS Simulator,name=iPhone 15" \
		-quiet | xcbeautify --is-ci
	@echo "$(GREEN)✓ iOS tests complete$(NC)"

test-all-platforms: test test-ios ## Run tests on all platforms

# MARK: - CLI Specific Targets

# Build CLI if needed
.build/$(CONFIGURATION)/app-store-cli:
	@$(MAKE) build CONFIGURATION=$(CONFIGURATION)

# CLI Commands
cli-status: .build/$(CONFIGURATION)/app-store-cli ## Check App Store Connect authentication status
	@.build/$(CONFIGURATION)/app-store-cli status

cli-metadata-list: .build/$(CONFIGURATION)/app-store-cli ## List all apps in App Store Connect
	@.build/$(CONFIGURATION)/app-store-cli metadata list

cli-metadata-download: .build/$(CONFIGURATION)/app-store-cli ## Download app metadata (BUNDLE_ID required)
	@if [ -z "$(BUNDLE_ID)" ]; then \
		echo "$(RED)Error: BUNDLE_ID is required$(NC)"; \
		echo "Usage: make cli-metadata-download BUNDLE_ID=com.example.app OUTPUT_DIR=./metadata"; \
		exit 1; \
	fi
	@.build/$(CONFIGURATION)/app-store-cli metadata download \
		--bundle-id $(BUNDLE_ID) \
		--output $(or $(OUTPUT_DIR),./metadata)

cli-metadata-upload: .build/$(CONFIGURATION)/app-store-cli ## Upload app metadata (BUNDLE_ID and INPUT_DIR required)
	@if [ -z "$(BUNDLE_ID)" ] || [ -z "$(INPUT_DIR)" ]; then \
		echo "$(RED)Error: BUNDLE_ID and INPUT_DIR are required$(NC)"; \
		echo "Usage: make cli-metadata-upload BUNDLE_ID=com.example.app INPUT_DIR=./metadata"; \
		exit 1; \
	fi
	@.build/$(CONFIGURATION)/app-store-cli metadata upload \
		--bundle-id $(BUNDLE_ID) \
		--input $(INPUT_DIR)

cli-version-list: .build/$(CONFIGURATION)/app-store-cli ## List app versions (BUNDLE_ID required)
	@if [ -z "$(BUNDLE_ID)" ]; then \
		echo "$(RED)Error: BUNDLE_ID is required$(NC)"; \
		echo "Usage: make cli-version-list BUNDLE_ID=com.example.app"; \
		exit 1; \
	fi
	@.build/$(CONFIGURATION)/app-store-cli version list --bundle-id $(BUNDLE_ID)

cli-version-create: .build/$(CONFIGURATION)/app-store-cli ## Create new app version (BUNDLE_ID and VERSION required)
	@if [ -z "$(BUNDLE_ID)" ] || [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: BUNDLE_ID and VERSION are required$(NC)"; \
		echo "Usage: make cli-version-create BUNDLE_ID=com.example.app VERSION=2.0.0"; \
		exit 1; \
	fi
	@.build/$(CONFIGURATION)/app-store-cli version create \
		--bundle-id $(BUNDLE_ID) \
		--version-string $(VERSION) \
		$(if $(PLATFORM),--platform $(PLATFORM))

cli-build-list: .build/$(CONFIGURATION)/app-store-cli ## List app builds (BUNDLE_ID required)
	@if [ -z "$(BUNDLE_ID)" ]; then \
		echo "$(RED)Error: BUNDLE_ID is required$(NC)"; \
		echo "Usage: make cli-build-list BUNDLE_ID=com.example.app"; \
		exit 1; \
	fi
	@.build/$(CONFIGURATION)/app-store-cli build list --bundle-id $(BUNDLE_ID)

install: build-release ## Install CLI to local system
	@echo "$(BLUE)Installing app-store-cli to /usr/local/bin...$(NC)"
	@sudo cp .build/release/app-store-cli /usr/local/bin/
	@echo "$(GREEN)✓ CLI installed successfully$(NC)"
	@echo "$(GREEN)  Run 'app-store-cli --help' to get started$(NC)"

uninstall: ## Remove CLI from local system
	@echo "$(BLUE)Removing app-store-cli from /usr/local/bin...$(NC)"
	@sudo rm -f /usr/local/bin/app-store-cli
	@echo "$(GREEN)✓ CLI uninstalled$(NC)"

# MARK: - Development Helpers

watch-test: ## Watch for changes and re-run tests
	@echo "$(BLUE)Watching for changes...$(NC)"
	@fswatch -o Sources Tests | xargs -n1 -I{} $(MAKE) test

# MARK: - Documentation

help: ## Show this help message
	@echo "AppStoreConnectCLI Makefile"
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
	@echo "  make test              # Run unit tests"
	@echo "  make test-acceptance   # Run acceptance tests (slow)"
	@echo "  make lint              # Check code style"
	@echo "  make build CONFIGURATION=release  # Build release configuration"
	@echo "  make install           # Install CLI to system"

# Mark all targets as phony (not files)
.PHONY: build build-ci build-release test test-acceptance test-all lint lint-fix \
        deadcode duplication quality clean test-ios test-all-platforms \
        cli-status cli-metadata-list cli-metadata-download cli-metadata-upload \
        cli-version-list cli-version-create cli-build-list \
        install uninstall watch-test help

# Suppress make's built-in rules
.SUFFIXES: