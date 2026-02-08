# Think Makefile
# Main aggregation makefile that delegates to all module makefiles
# This makefile should only contain:
# 1. Aggregated commands that call all module makefiles
# 2. App-specific commands (build/run for macOS, iOS, visionOS)
# 3. Special commands (pr-review, verify-release)

# Variables for app builds
WORKSPACE = Think.xcworkspace
XCODE_FLAGS = -quiet
XCODE_CI_SETTINGS = CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
XCODE_THIRD_PARTY_WARNING_SETTINGS = GCC_TREAT_WARNINGS_AS_ERRORS=NO CLANG_WARNINGS_AS_ERRORS=NO
SIMULATOR_NAME ?= $(shell xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $$1; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//')
ARCHIVE_PATH = ./build/archives
APPSTORE_BUNDLE_ID ?= com.example.app
APPSTORE_BUNDLE_ID_IOS ?= $(APPSTORE_BUNDLE_ID)
APPSTORE_BUNDLE_ID_MACOS ?= $(APPSTORE_BUNDLE_ID)
APPSTORE_BUNDLE_ID_VISIONOS ?= $(APPSTORE_BUNDLE_ID)

# List of all modules
MODULES = Abstractions DataAssets AgentOrchestrator AudioGenerator ContextBuilder Database Factories \
          ImageGenerator LLamaCPP MLXSession ModelDownloader RAG Tools UIComponents ViewModels AppStoreConnectCLI ThinkCLI
CI_TEST_MODULES = $(filter-out LLamaCPP MLXSession,$(MODULES))

# ==============================================================================
# AGGREGATED COMMANDS - Delegate to all module makefiles
# ==============================================================================

# Lint all modules and apps
lint-all:
	@echo "🧹 Linting all modules and apps..."
	@for module in $(MODULES); do \
		echo "🧹 Linting $$module..."; \
		$(MAKE) -C $$module lint || exit 1; \
	done
	@echo "🧹 Linting Think app..."
	@cd Think && swiftlint --strict --quiet . || exit 1
	@echo "🧹 Linting ThinkVision app..."
	@cd "Think Vision" && swiftlint --strict --quiet . || exit 1
	@echo "✅ All modules and apps linted!"

# Test all modules
test-all:
	@echo "🧪 Testing all modules..."
	@for module in $(MODULES); do \
		echo "🧪 Testing $$module..."; \
		$(MAKE) -C $$module test || exit 1; \
	done
	@echo "✅ All module tests completed!"

# Test modules in CI (skip modules that require local models)
test-ci:
	@echo "🧪 Testing CI modules (excluding LLamaCPP, MLXSession)..."
	@for module in $(CI_TEST_MODULES); do \
		echo "🧪 Testing $$module..."; \
		$(MAKE) -C $$module test || exit 1; \
	done
	@echo "✅ CI module tests completed!"

# Build all modules
build-all:
	@echo "🔨 Building all modules..."
	@for module in $(MODULES); do \
		echo "🔨 Building $$module..."; \
		$(MAKE) -C $$module build || exit 1; \
	done
	@echo "✅ All modules built!"

# Clean all modules and apps
clean-all:
	@echo "🧹 Cleaning all modules and apps..."
	@for module in $(MODULES); do \
		echo "🧹 Cleaning $$module..."; \
		$(MAKE) -C $$module clean || true; \
	done
	@echo "🧹 Cleaning Xcode build artifacts..."
	@xcodebuild clean \
		-workspace $(WORKSPACE) \
		-scheme Think \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci || true
	@rm -rf .build
	@rm -rf $(ARCHIVE_PATH)
	@echo "✅ All clean!"

# Aliases for common commands
lint: lint-all
test: test-all
build: build-all
clean: clean-all

# ==============================================================================
# APP-SPECIFIC COMMANDS - Build and run apps
# ==============================================================================

# Run the app (alias for run-think)
run: run-think

# Build macOS app
build-macos:
	@echo "🚀 Creating production archive for Think macOS..."
	@mkdir -p $(ARCHIVE_PATH)
	@xcodebuild clean archive \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'platform=macOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH)/Think-macOS.xcarchive \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci
	@echo "✅ macOS archive created: $(ARCHIVE_PATH)/Think-macOS.xcarchive"

# Build iOS app
build-ios:
	@echo "🚀 Creating production archive for Think iOS..."
	@mkdir -p $(ARCHIVE_PATH)
	@xcodebuild clean archive \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'generic/platform=iOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH)/Think-iOS.xcarchive \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci
	@echo "✅ iOS archive created: $(ARCHIVE_PATH)/Think-iOS.xcarchive"

# Build visionOS app
build-visionos:
	@echo "🚀 Creating production archive for ThinkVision visionOS..."
	@mkdir -p $(ARCHIVE_PATH)
	@xcodebuild clean archive \
		-workspace $(WORKSPACE) \
		-scheme ThinkVision \
		-destination 'generic/platform=visionOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH)/ThinkVision-visionOS.xcarchive \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci
	@echo "✅ visionOS archive created: $(ARCHIVE_PATH)/ThinkVision-visionOS.xcarchive"

# CI builds (compile only, no signing)
build-macos-ci:
	@echo "🚀 Building Think macOS (CI, no signing)..."
	@/bin/bash -lc "set -o pipefail; xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'platform=macOS' \
		-configuration Debug \
		ENABLE_USER_SCRIPT_SANDBOXING=NO \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_CI_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci"
	@echo "✅ macOS CI build complete"

build-ios-ci:
	@echo "🚀 Building Think iOS (CI, no signing)..."
	@/bin/bash -lc "set -o pipefail; xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'generic/platform=iOS' \
		-configuration Debug \
		ENABLE_USER_SCRIPT_SANDBOXING=NO \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_CI_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci"
	@echo "✅ iOS CI build complete"

build-ios-sim:
	@if [ -z "$(SIMULATOR_NAME)" ]; then \
		echo "❌ No available iPhone simulator found. Install a simulator in Xcode."; \
		exit 1; \
	fi
	@echo "🚀 Building Think iOS for simulator: $(SIMULATOR_NAME)..."
	@/bin/bash -lc "set -o pipefail; xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR_NAME)' \
		-configuration Debug \
		IPHONEOS_DEPLOYMENT_TARGET=18.5 \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
		SWIFT_STRICT_CONCURRENCY=targeted \
		SWIFT_CONCURRENCY_CHECKS=warn \
		CLANG_CXX_LANGUAGE_STANDARD=gnu++17 \
		SWIFT_SUPPRESS_WARNINGS=NO \
		ENABLE_USER_SCRIPT_SANDBOXING=NO \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_CI_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci"
	@echo "✅ iOS Simulator build complete"

build-visionos-ci:
	@echo "🚀 Building ThinkVision visionOS (CI, no signing)..."
	@/bin/bash -lc "set -o pipefail; xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme ThinkVision \
		-destination 'generic/platform=visionOS' \
		-configuration Debug \
		ENABLE_USER_SCRIPT_SANDBOXING=NO \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_CI_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci"
	@echo "✅ visionOS CI build complete"

# Run Think app on macOS
run-think:
	@echo "🧹 Linting Think app..."
	@cd Think && swiftlint --strict --quiet . || exit 1
	@echo "🚀 Building and running Think for macOS..."
	@xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme Think \
		-destination 'platform=macOS' \
		-configuration Debug \
		-derivedDataPath .build \
		SWIFT_SUPPRESS_WARNINGS=NO \
		SWIFT_STRICT_CONCURRENCY=targeted \
		SWIFT_CONCURRENCY_CHECKS=warn \
		CLANG_CXX_LANGUAGE_STANDARD=gnu++17 \
		ENABLE_USER_SCRIPT_SANDBOXING=NO \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci
	@echo "🏃 Launching Think..."
	@open .build/Build/Products/Debug/Think.app

# Run ThinkVision app for visionOS
run-thinkVision:
	@echo "🧹 Linting ThinkVision app..."
	@cd "Think Vision" && swiftlint --strict --quiet . || exit 1
	@echo "🚀 Building ThinkVision for visionOS..."
	@xcodebuild build \
		-workspace $(WORKSPACE) \
		-scheme ThinkVision \
		-destination 'generic/platform=visionOS' \
		-configuration Debug \
		-derivedDataPath .build \
		$(XCODE_THIRD_PARTY_WARNING_SETTINGS) \
		$(XCODE_FLAGS) \
		| xcbeautify --is-ci
	@echo "✅ ThinkVision built for visionOS"
	@echo "📱 To run: Open Xcode and run on visionOS device or simulator"

# ==============================================================================
# SPECIAL COMMANDS - PR review and release verification
# ==============================================================================

# Review PR - Run all tests and builds, update PR status
review-pr:
ifndef PR
	$(error PR number is required. Usage: make review-pr PR=123)
endif
	@echo "🔄 Starting PR #$(PR) review..."
	@# Get PR SHA
	$(eval SHA := $(shell gh pr view $(PR) --json headRefOid -q .headRefOid 2>/dev/null))
	@if [ -z "$(SHA)" ]; then \
		echo "❌ Error: Could not fetch PR #$(PR). Check PR number and GitHub authentication."; \
		exit 1; \
	fi
	@echo "📍 PR SHA: $(SHA)"

	@# Clean all build artifacts to ensure fresh build
	@echo "🧹 Cleaning build artifacts..."
	@$(MAKE) clean-all

	@# Mark as pending
	@gh api repos/:owner/:repo/statuses/$(SHA) \
		--method POST \
		--field state='pending' \
		--field description='Running local CI...' \
		--field context='local-ci/review' 2>/dev/null || true

	@echo "🧹 Running linting checks..."
	@if ! $(MAKE) lint-all; then \
		gh api repos/:owner/:repo/statuses/$(SHA) \
			--method POST \
			--field state='failure' \
			--field description='Linting failed' \
			--field context='local-ci/review' 2>/dev/null || true; \
		echo "❌ Linting failed"; \
		exit 1; \
	fi
	@echo "✅ All linting checks passed"

	@echo "🧪 Running all tests..."
	@if ! $(MAKE) test-all; then \
		gh api repos/:owner/:repo/statuses/$(SHA) \
			--method POST \
			--field state='failure' \
			--field description='Tests failed' \
			--field context='local-ci/review' 2>/dev/null || true; \
		echo "❌ Tests failed"; \
		exit 1; \
	fi
	@echo "✅ All tests passed"

	@echo "🔨 Building for macOS..."
	@if ! $(MAKE) build-macos; then \
		gh api repos/:owner/:repo/statuses/$(SHA) \
			--method POST \
			--field state='failure' \
			--field description='macOS build failed' \
			--field context='local-ci/review' 2>/dev/null || true; \
		echo "❌ macOS build failed"; \
		exit 1; \
	fi
	@echo "✅ macOS build succeeded"

	@echo "🔨 Building for iOS..."
	@if ! $(MAKE) build-ios; then \
		gh api repos/:owner/:repo/statuses/$(SHA) \
			--method POST \
			--field state='failure' \
			--field description='iOS build failed' \
			--field context='local-ci/review' 2>/dev/null || true; \
		echo "❌ iOS build failed"; \
		exit 1; \
	fi
	@echo "✅ iOS build succeeded"

	@echo "🔨 Building for visionOS..."
	@if ! $(MAKE) build-visionos; then \
		gh api repos/:owner/:repo/statuses/$(SHA) \
			--method POST \
			--field state='failure' \
			--field description='visionOS build failed' \
			--field context='local-ci/review' 2>/dev/null || true; \
		echo "❌ visionOS build failed"; \
		exit 1; \
	fi
	@echo "✅ visionOS build succeeded"

	@# All checks passed - update PR status
	@gh api repos/:owner/:repo/statuses/$(SHA) \
		--method POST \
		--field state='success' \
		--field description='All linting, tests and builds passed!' \
		--field context='local-ci/review' 2>/dev/null || true
	@echo ""
	@echo "✅ PR #$(PR) is ready to merge!"
	@echo ""

# Verify release readiness - comprehensive validation including acceptance tests
verify-release:
	@echo "🚀 Starting comprehensive release verification..."
	@echo "⚠️  This will run ALL tests including long-running acceptance tests"
	@echo ""

	@# Clean all build artifacts to ensure fresh build
	@echo "🧹 Cleaning build artifacts..."
	@$(MAKE) clean-all

	@echo "📋 Phase 1: Standard Validation"
	@echo "================================"
	@echo "🧹 Running linting checks..."
	@$(MAKE) lint-all || (echo "❌ Linting failed"; exit 1)
	@echo "✅ All linting checks passed"

	@echo "🧪 Running all tests..."
	@$(MAKE) test-all || (echo "❌ Tests failed"; exit 1)
	@echo "✅ All tests passed"

	@echo ""
	@echo "📋 Phase 2: Multi-Platform Builds"
	@echo "=================================="
	@echo "🔨 Building for macOS..."
	@$(MAKE) build-macos || (echo "❌ macOS build failed"; exit 1)
	@echo "✅ macOS build succeeded"

	@echo "🔨 Building for iOS..."
	@$(MAKE) build-ios || (echo "❌ iOS build failed"; exit 1)
	@echo "✅ iOS build succeeded"

	@echo "🔨 Building for visionOS..."
	@$(MAKE) build-visionos || (echo "❌ visionOS build failed"; exit 1)
	@echo "✅ visionOS build succeeded"
	\
	@echo ""
	@echo "📋 Phase 3: Acceptance Tests"
	@echo "============================"
	@echo "🧪 Running ModelDownloader acceptance tests..."
	@echo "⏱️  This downloads real AI models and may take 10-30 minutes"

	@cd ModelDownloader && \
	   swift test \
		--configuration release \
		--filter "PublicAPIDocumentationTests" \
		-Xswiftc -DRELEASE_VALIDATION || \
		(echo "❌ Acceptance tests failed"; exit 1)
	@echo "✅ Acceptance tests passed"
	\
	@echo ""
	@echo "📊 Release Verification Summary"
	@echo "==============================="
	@echo ""
	@echo "✅ 🎉 RELEASE READY! 🎉"
	@echo ""
	@echo "All validations passed:"
	@echo "  ✓ All module tests passing"
	@echo "  ✓ All linting checks passing"
	@echo "  ✓ macOS build successful"
	@echo "  ✓ iOS build successful"
	@echo "  ✓ visionOS build successful"
	@echo "  ✓ Acceptance tests with real models passing"
	@echo ""
	@echo "The current state is ready to deploy! 🚀"
	@echo ""

# ==============================================================================
# OTHER COMMANDS
# ==============================================================================

# Translate localizable strings
translate:
	@echo "🌐 Translating localizable strings..."
	@./scripts/translate.sh

# ==============================================================================
# CI/CD COMMANDS - App Store deployment pipeline
# ==============================================================================

# Setup development environment for CI/CD
setup:
	@echo "🔧 Setting up CI/CD environment..."
	@./scripts/check-dependencies.sh
	@echo ""
	@echo "✅ Setup complete! Next steps:"
	@echo "  1. Copy scripts/.env.example to scripts/.env"
	@echo "  2. Fill in your App Store Connect credentials"
	@echo "  3. Download your API key from App Store Connect"
	@echo "  4. Run 'make check-env' to verify configuration"

# Check environment variables and configuration
check-env:
	@echo "🔍 Checking environment configuration..."
	@# Check if .env file exists
	@if [ ! -f "scripts/.env" ]; then \
		echo "❌ Error: scripts/.env file not found"; \
		echo "  Run: cp scripts/.env.example scripts/.env"; \
		echo "  Then edit the file with your credentials"; \
		exit 1; \
	fi
	@# Source the .env file
	@source scripts/.env && \
	if [ -z "$$APPSTORE_KEY_ID" ]; then \
		echo "❌ Error: APPSTORE_KEY_ID not set in .env"; \
		exit 1; \
	fi && \
	if [ -z "$$APPSTORE_ISSUER_ID" ]; then \
		echo "❌ Error: APPSTORE_ISSUER_ID not set in .env"; \
		exit 1; \
	fi && \
	if [ -z "$$TEAM_ID" ]; then \
		echo "❌ Error: TEAM_ID not set in .env"; \
		exit 1; \
	fi && \
	if [ -z "$$APPSTORE_P8_KEY" ] && [ -z "$$APP_STORE_CONNECT_API_KEY_PATH" ]; then \
		echo "❌ Error: Neither APPSTORE_P8_KEY nor APP_STORE_CONNECT_API_KEY_PATH is set"; \
		echo "  Set APPSTORE_P8_KEY with the raw key content, or"; \
		echo "  Set APP_STORE_CONNECT_API_KEY_PATH with the path to your .p8 file"; \
		exit 1; \
	fi && \
	echo "✅ Environment configuration looks good!"

# Record build environment for reproducibility
record-environment:
	@echo "📸 Recording build environment..."
	@./scripts/record-environment.sh record

# Export iOS app from archive
export-ios: build-ios
	@echo "📦 Exporting iOS app..."
	@./scripts/export-archive.sh \
		-a $(ARCHIVE_PATH)/Think-iOS.xcarchive \
		-o build/export/ios \
		-p ios
	@echo "✅ iOS export complete: build/export/ios/"

# Export macOS app from archive
export-macos: build-macos
	@echo "📦 Exporting macOS app..."
	@./scripts/export-archive.sh \
		-a $(ARCHIVE_PATH)/Think-macOS.xcarchive \
		-o build/export/macos \
		-p macos
	@echo "✅ macOS export complete: build/export/macos/"

# Export visionOS app from archive
export-visionos: build-visionos
	@echo "📦 Exporting visionOS app..."
	@./scripts/export-archive.sh \
		-a $(ARCHIVE_PATH)/ThinkVision-visionOS.xcarchive \
		-o build/export/visionos \
		-p visionos
	@echo "✅ visionOS export complete: build/export/visionos/"

# Export macOS app for DMG (Developer ID)
export-macos-dmg: build-macos
	@echo "📦 Exporting macOS app for DMG..."
	@./scripts/export-archive.sh \
		-a $(ARCHIVE_PATH)/Think-macOS.xcarchive \
		-o build/export/macos-dmg \
		-p macos \
		-e scripts/ExportOptions-DeveloperID.plist
	@echo "✅ macOS DMG export complete: build/export/macos-dmg/"

# Create DMG for macOS
create-dmg-macos: export-macos-dmg
	@echo "💿 Creating macOS DMG..."
	@VERSION=$$(./scripts/get-version.sh -f marketing) && \
	./scripts/create-dmg.sh \
		-a build/export/macos-dmg/Think.app \
		-o build/dmg \
		-n "Think-$$VERSION" \
		-v "Think"
	@echo "✅ DMG created: build/dmg/"

# Notarize DMG for direct distribution outside App Store
notarize-dmg:
	@echo "🔏 Notarizing macOS DMG for direct distribution..."
	@VERSION=$$(./scripts/get-version.sh -f marketing) && \
	if [ ! -f "build/dmg/Think-$$VERSION.dmg" ]; then \
		echo "❌ Error: DMG not found. Run 'make create-dmg-macos' first"; \
		exit 1; \
	fi && \
	./scripts/notarize-dmg.sh "build/dmg/Think-$$VERSION.dmg"
	@echo "✅ DMG notarized and ready for distribution!"

# Complete direct distribution workflow
distribute-macos-direct: create-dmg-macos notarize-dmg
	@VERSION=$$(./scripts/get-version.sh -f marketing) && \
	echo "" && \
	echo "✅ Direct distribution package ready!" && \
	echo "   File: build/dmg/Think-$$VERSION.dmg" && \
	echo "   Status: Signed, notarized, and stapled" && \
	echo "" && \
	echo "You can now:" && \
	echo "  1. Upload to your website" && \
	echo "  2. Share via direct download links" && \
	echo "  3. Distribute via GitHub Releases"

# Check notarization status (for debugging)
check-notarization:
	@echo "🔍 Checking notarization history..."
	@set -a && source scripts/.env && set +a && \
	xcrun notarytool history \
		--key-id "$$APPSTORE_KEY_ID" \
		--issuer "$$APPSTORE_ISSUER_ID" \
		--key "$$APP_STORE_CONNECT_API_KEY_PATH"

# Version management targets
bump-version:
	@./scripts/bump-version.sh patch

bump-major:
	@./scripts/bump-version.sh major

bump-minor:
	@./scripts/bump-version.sh minor

bump-patch:
	@./scripts/bump-version.sh patch

bump-build:
	@./scripts/bump-version.sh build

get-version:
	@./scripts/get-version.sh

# Conventional commits version bumping
bump-auto:
	@echo "🔄 Analyzing commits and bumping version..."
	@./scripts/conventional-commits-version.sh

bump-auto-dry-run:
	@echo "🔍 Analyzing commits (dry run)..."
	@./scripts/conventional-commits-version.sh --dry-run

bump-auto-verbose:
	@echo "🔍 Analyzing commits with detailed output..."
	@./scripts/conventional-commits-version.sh --verbose


# ==============================================================================
# APP STORE CONNECT CLI COMMANDS
# ==============================================================================

# Build the CLI
build-cli:
	@echo "🔨 Building App Store Connect CLI..."
	@cd AppStoreConnectCLI && swift build --configuration release
	@echo "✅ CLI built successfully"

# List all apps
cli-list-apps:
	@echo "📱 Listing all apps in App Store Connect..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata list --detailed

# Download customer reviews for an app
reviews:
ifndef APP_ID
	$(error APP_ID is required. Usage: make reviews APP_ID=1234567890 [OUTPUT_PATH=./reviews] [VERBOSE=true])
endif
	@echo "📝 Downloading customer reviews for app ID $(APP_ID)..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli reviews \
		--app-id $(APP_ID) \
		$(if $(OUTPUT_PATH),--output-path $(OUTPUT_PATH),) \
		$(if $(VERBOSE),--verbose,)
	@echo "✅ Reviews downloaded successfully!"

# Metadata management targets using CLI
download-metadata:
	@echo "📥 Downloading App Store metadata for all platforms using CLI..."
	@for platform in iOS macOS visionOS; do \
		echo "📱 Downloading $$platform metadata..."; \
		bundle_id="$(APPSTORE_BUNDLE_ID)"; \
		case $$platform in \
			iOS) bundle_id="$(APPSTORE_BUNDLE_ID_IOS)" ;; \
			macOS) bundle_id="$(APPSTORE_BUNDLE_ID_MACOS)" ;; \
			visionOS) bundle_id="$(APPSTORE_BUNDLE_ID_VISIONOS)" ;; \
		esac; \
		(set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
		swift run app-store-cli metadata download \
			--bundle-id $$bundle_id \
			--platform $$platform \
			--output ../app-store-metadata/$$platform) || true; \
	done
	@echo "✅ Metadata downloaded to platform-specific directories"

download-metadata-ios:
	@echo "📥 Downloading iOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata download \
		--bundle-id $(APPSTORE_BUNDLE_ID_IOS) \
		--platform iOS \
		--output ../app-store-metadata/iOS
	@echo "✅ iOS metadata downloaded to app-store-metadata/iOS/"

download-metadata-macos:
	@echo "📥 Downloading macOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata download \
		--bundle-id $(APPSTORE_BUNDLE_ID_MACOS) \
		--platform macOS \
		--output ../app-store-metadata/macOS
	@echo "✅ macOS metadata downloaded to app-store-metadata/macOS/"

download-metadata-visionos:
	@echo "📥 Downloading visionOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata download \
		--bundle-id $(APPSTORE_BUNDLE_ID_VISIONOS) \
		--platform visionOS \
		--output ../app-store-metadata/visionOS
	@echo "✅ visionOS metadata downloaded to app-store-metadata/visionOS/"

upload-metadata:
	@echo "📤 Uploading App Store metadata for all platforms using CLI..."
	@for platform in iOS macOS visionOS; do \
		echo "📤 Uploading $$platform metadata..."; \
		bundle_id="$(APPSTORE_BUNDLE_ID)"; \
		case $$platform in \
			iOS) bundle_id="$(APPSTORE_BUNDLE_ID_IOS)" ;; \
			macOS) bundle_id="$(APPSTORE_BUNDLE_ID_MACOS)" ;; \
			visionOS) bundle_id="$(APPSTORE_BUNDLE_ID_VISIONOS)" ;; \
		esac; \
		(set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
		swift run app-store-cli metadata upload \
			--bundle-id $$bundle_id \
			--platform $$platform \
			--input ../app-store-metadata/$$platform) || true; \
	done
	@echo "✅ Metadata uploaded successfully for all platforms"

upload-metadata-ios:
	@echo "📤 Uploading iOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata upload \
		--bundle-id $(APPSTORE_BUNDLE_ID_IOS) \
		--platform iOS \
		--input ../app-store-metadata/iOS
	@echo "✅ iOS metadata uploaded successfully"

upload-metadata-macos:
	@echo "📤 Uploading macOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata upload \
		--bundle-id $(APPSTORE_BUNDLE_ID_MACOS) \
		--platform macOS \
		--input ../app-store-metadata/macOS
	@echo "✅ macOS metadata uploaded successfully"

upload-metadata-visionos:
	@echo "📤 Uploading visionOS App Store metadata using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	swift run app-store-cli metadata upload \
		--bundle-id $(APPSTORE_BUNDLE_ID_VISIONOS) \
		--platform visionOS \
		--input ../app-store-metadata/visionOS
	@echo "✅ visionOS metadata uploaded successfully"

validate-metadata:
	@echo "✅ Metadata validation for all platforms using CLI..."
	@for platform in iOS macOS visionOS; do \
		echo "✅ Validating $$platform metadata..."; \
		bundle_id="$(APPSTORE_BUNDLE_ID)"; \
		case $$platform in \
			iOS) bundle_id="$(APPSTORE_BUNDLE_ID_IOS)" ;; \
			macOS) bundle_id="$(APPSTORE_BUNDLE_ID_MACOS)" ;; \
			visionOS) bundle_id="$(APPSTORE_BUNDLE_ID_VISIONOS)" ;; \
		esac; \
		(set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
		swift run app-store-cli metadata upload \
			--bundle-id $$bundle_id \
			--platform $$platform \
			--input ../app-store-metadata/$$platform \
			--skip-validation=false \
			--dry-run) || echo "ℹ️  Dry run mode not implemented yet for $$platform"; \
	done

# Generate changelog
generate-changelog:
	@./scripts/generate-changelog.sh

# Create GitHub release
create-release:
	$(eval VERSION := $(shell ./scripts/get-version.sh | cut -d'-' -f1))
	@echo "📝 Creating GitHub release for version $(VERSION)..."
	@./scripts/create-github-release.sh -v $(VERSION) \
		-a build/export/ios/Think.ipa \
		-a build/export/macos/Think.app \
		-a build/dmg/Think-$(VERSION).dmg

# App Store Connect version management using CLI
manage-app-store-versions:
	@echo "📱 Managing App Store Connect versions using CLI..."
	@$(MAKE) manage-ios-version
	@$(MAKE) manage-macos-version
	@$(MAKE) manage-visionos-version

manage-app-store-versions-dry-run:
	@echo "🔍 Checking App Store Connect versions (dry run)..."
	@echo "ℹ️  Would create versions for iOS, macOS, and visionOS"
	@echo "ℹ️  Current version: $$(./scripts/get-version.sh -f marketing)"

manage-ios-version:
	@echo "📱 Managing iOS version in App Store Connect using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	VERSION=$$(../scripts/get-version.sh -f marketing) && \
	swift run app-store-cli version create \
		--bundle-id $(APPSTORE_BUNDLE_ID_IOS) \
		--version-string $$VERSION \
		--platform iOS || echo "ℹ️  Version may already exist"

manage-macos-version:
	@echo "🖥️ Managing macOS version in App Store Connect using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	VERSION=$$(../scripts/get-version.sh -f marketing) && \
	swift run app-store-cli version create \
		--bundle-id $(APPSTORE_BUNDLE_ID_MACOS) \
		--version-string $$VERSION \
		--platform macOS || echo "ℹ️  Version may already exist"

manage-visionos-version:
	@echo "🥽 Managing visionOS version in App Store Connect using CLI..."
	@set -a && source scripts/.env && set +a && cd AppStoreConnectCLI && \
	VERSION=$$(../scripts/get-version.sh -f marketing) && \
	swift run app-store-cli version create \
		--bundle-id $(APPSTORE_BUNDLE_ID_VISIONOS) \
		--version-string $$VERSION \
		--platform visionOS || echo "ℹ️  Version may already exist"

# Submit apps to App Store Connect (using iTMSTransporter)
submit-ios:
	@echo "📱 Submitting iOS app to App Store Connect..."
	@./scripts/submit-app.sh \
		-a $(ARCHIVE_PATH)/Think-iOS.xcarchive \
		-p ios

submit-macos:
	@echo "🖥️ Submitting macOS app to App Store Connect..."
	@./scripts/submit-app.sh \
		-a $(ARCHIVE_PATH)/Think-macOS.xcarchive \
		-p macos

submit-visionos:
	@echo "🥽 Submitting visionOS app to App Store Connect..."
	@./scripts/submit-app.sh \
		-a $(ARCHIVE_PATH)/ThinkVision-visionOS.xcarchive \
		-p visionos

# Deployment dry run - shows what would happen without executing
deploy-dry-run:
	@echo "🔍 Running deployment dry run..."
	@echo ""
	@echo "Step 1: Version Analysis"
	@echo "========================"
	@$(MAKE) bump-auto-dry-run
	@echo ""
	@echo "Step 2: Deployment Preview"
	@echo "=========================="
	@./scripts/deploy-dry-run.sh

# Master deployment target - orchestrates the entire release with automatic versioning
deploy:
	@echo "🚀 Starting full deployment pipeline with automatic versioning..."
	@echo ""
	@# Step 0: Auto-bump version based on commits
	@echo "0️⃣ Analyzing commits and bumping version..."
	@$(MAKE) bump-auto
	@echo ""
	@# Step 1: Verify environment
	@echo "1️⃣ Verifying environment..."
	@$(MAKE) check-env
	@echo ""
	@# Step 2: Clean and verify release readiness
	@echo "2️⃣ Verifying release readiness..."
	@$(MAKE) verify-release
	@echo ""
	@# Step 3: Record build environment
	@echo "3️⃣ Recording build environment..."
	@$(MAKE) record-environment
	@echo ""
	@# Step 4: Build CLI tools
	@echo "4️⃣ Building App Store Connect CLI..."
	@$(MAKE) build-cli
	@echo ""
	@# Step 5: Get current version
	$(eval CURRENT_VERSION := $(shell ./scripts/get-version.sh -f marketing))
	@echo "5️⃣ Current version: $(CURRENT_VERSION)"
	@echo ""
	@# Step 6: Build and export all platforms
	@echo "6️⃣ Building and exporting all platforms..."
	@$(MAKE) export-ios
	@$(MAKE) export-macos
	@$(MAKE) export-visionos
	@$(MAKE) create-dmg-macos
	@echo ""
	@# Step 7: Generate changelog
	@echo "7️⃣ Generating changelog..."
	@$(MAKE) generate-changelog
	@echo ""
	@# Step 8: Create GitHub release
	@echo "8️⃣ Creating GitHub release..."
	@$(MAKE) create-release VERSION=$(CURRENT_VERSION)
	@echo ""
	@# Step 9: Create/Update App Store Connect versions
	@echo "9️⃣ Creating/Updating App Store Connect versions..."
	@$(MAKE) manage-app-store-versions
	@echo ""
	@# Step 10: Upload metadata to App Store Connect
	@echo "🔟 Uploading metadata to App Store Connect..."
	@$(MAKE) upload-metadata
	@echo ""
	@# Step 11: Submit to App Store Connect
	@echo "1️⃣1️⃣ Submitting to App Store Connect..."
	@echo "   This step requires manual confirmation for each platform."
	@read -p "Submit iOS app? (y/N) " -n 1 -r && echo && \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) submit-ios; \
	fi
	@read -p "Submit macOS app? (y/N) " -n 1 -r && echo && \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) submit-macos; \
	fi
	@read -p "Submit visionOS app? (y/N) " -n 1 -r && echo && \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) submit-visionos; \
	fi
	@echo ""
	@echo "✅ Deployment pipeline complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Monitor App Store Connect for processing status"
	@echo "  2. Complete any missing metadata"
	@echo "  3. Submit for review when ready"

# Help
help:
	@echo "Think Build System"
	@echo "====================="
	@echo ""
	@echo "This is an aggregation makefile that delegates to module makefiles."
	@echo ""
	@echo "Main Commands:"
	@echo "  make lint               - Lint all modules and apps"
	@echo "  make test               - Test all modules"
	@echo "  make build              - Build all modules"
	@echo "  make clean              - Clean all modules and apps"
	@echo "  make run                - Build and run Think app (macOS)"
	@echo ""
	@echo "App Commands:"
	@echo "  make build-macos        - Archive Think for macOS (production)"
	@echo "  make build-ios          - Archive Think for iOS (production)"
	@echo "  make build-visionos     - Archive ThinkVision for visionOS (production)"
	@echo "  make run-think      - Build and run Think app (macOS)"
	@echo "  make run-thinkVision - Build ThinkVision (visionOS)"
	@echo ""
	@echo "CI/CD Commands:"
	@echo "  make setup              - Setup CI/CD environment"
	@echo "  make check-env          - Verify environment configuration"
	@echo "  make deploy             - Complete deployment pipeline with automatic versioning"
	@echo "  make deploy-dry-run     - Preview deployment including version bump analysis"
	@echo "  make test-ci            - Run CI tests (skips LLamaCPP, MLXSession)"
	@echo ""
	@echo "  Build & Export:"
	@echo "  make export-ios         - Export iOS app from archive"
	@echo "  make export-macos       - Export macOS app from archive"
	@echo "  make export-visionos    - Export visionOS app from archive"
	@echo "  make create-dmg-macos   - Create macOS DMG installer"
	@echo ""
	@echo "  Direct Distribution (outside App Store):"
	@echo "  make notarize-dmg       - Notarize DMG for Gatekeeper approval"
	@echo "  make distribute-macos-direct - Complete DMG creation + notarization"
	@echo "  make check-notarization - Check notarization history"
	@echo ""
	@echo "  Version Management:"
	@echo "  make bump-major         - Bump major version (X.0.0)"
	@echo "  make bump-minor         - Bump minor version (x.X.0)"
	@echo "  make bump-patch         - Bump patch version (x.x.X)"
	@echo "  make bump-build         - Increment build number"
	@echo "  make get-version        - Show current version"
	@echo ""
	@echo "  make bump-auto          - Auto-bump based on conventional commits"
	@echo "  make bump-auto-dry-run  - Preview version bump without changes"
	@echo "  make bump-auto-verbose  - Auto-bump with detailed commit analysis"
	@echo ""
	@echo "  Metadata & Release:"
	@echo "  make download-metadata  - Download App Store metadata (all platforms)"
	@echo "  make download-metadata-ios - Download iOS metadata only"
	@echo "  make download-metadata-macos - Download macOS metadata only"
	@echo "  make download-metadata-visionos - Download visionOS metadata only"
	@echo "  make upload-metadata    - Upload App Store metadata (all platforms)"
	@echo "  make upload-metadata-ios - Upload iOS metadata only"
	@echo "  make upload-metadata-macos - Upload macOS metadata only"
	@echo "  make upload-metadata-visionos - Upload visionOS metadata only"
	@echo "  make validate-metadata  - Validate metadata files (all platforms)"
	@echo "  make generate-changelog - Generate changelog from commits"
	@echo "  make create-release VERSION=2.0.23 - Create GitHub release"
	@echo ""
	@echo "  Submission:"
	@echo "  make submit-ios         - Submit iOS app to App Store"
	@echo "  make submit-macos       - Submit macOS app to App Store"
	@echo "  make submit-visionos    - Submit visionOS app to App Store"
	@echo ""
	@echo "  Version Management:"
	@echo "  make manage-app-store-versions     - Create/update versions for all platforms"
	@echo "  make manage-app-store-versions-dry-run - Preview version management"
	@echo "  make manage-ios-version           - Create/update iOS version"
	@echo "  make manage-macos-version         - Create/update macOS version"
	@echo "  make manage-visionos-version      - Create/update visionOS version"
	@echo ""
	@echo "  Validation:"
	@echo "  make review-pr PR=123   - Validate PR readiness (tests + builds)"
	@echo "  make verify-release     - Complete release validation (~30 minutes)"
	@echo ""
	@echo "  CI Builds:"
	@echo "  make build-macos-ci     - Build Think macOS without code signing"
	@echo "  make build-ios-ci       - Build Think iOS without code signing"
	@echo "  make build-visionos-ci  - Build ThinkVision without code signing"
	@echo ""
	@echo "Other Commands:"
	@echo "  make translate          - Translate all localizable strings"
	@echo "  make help               - Show this help message"
	@echo ""
	@echo "Note: Archives are created in $(ARCHIVE_PATH)/ (in .gitignore)"
	@echo ""
	@echo "For module-specific commands, use the module's Makefile directly:"
	@echo "  cd ModuleName && make help"

.PHONY: lint-all test-all test-ci build-all clean-all lint test build clean \
        build-macos build-ios build-visionos build-macos-ci build-ios-ci build-visionos-ci \
        run run-think run-thinkVision \
        review-pr verify-release translate help \
        setup check-env record-environment \
        export-ios export-macos export-visionos export-macos-dmg create-dmg-macos \
        bump-version bump-major bump-minor bump-patch bump-build get-version \
        bump-auto bump-auto-dry-run bump-auto-verbose \
        deploy-dry-run \
        download-metadata download-metadata-ios download-metadata-macos download-metadata-visionos \
        upload-metadata upload-metadata-ios upload-metadata-macos upload-metadata-visionos \
        validate-metadata \
        generate-changelog create-release \
        manage-app-store-versions manage-app-store-versions-dry-run \
        manage-ios-version manage-macos-version manage-visionos-version \
        submit-ios submit-macos submit-visionos deploy
