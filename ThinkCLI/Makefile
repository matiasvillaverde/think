# ThinkCLI Package Makefile

CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS = --configuration $(CONFIGURATION)
SWIFT_TEST_FLAGS = --configuration $(CONFIGURATION) --parallel

# Default install location on macOS:
# - Apple Silicon Homebrew: /opt/homebrew/bin
# - Intel Homebrew or system: /usr/local/bin
# Override with: make install BINDIR=/some/path
DEFAULT_PREFIX = $(shell if [ -d /opt/homebrew/bin ]; then echo /opt/homebrew; else echo /usr/local; fi)
BINDIR ?= $(DEFAULT_PREFIX)/bin
INSTALL_PREFIX = $(abspath $(BINDIR)/..)
LIBEXECDIR ?= $(INSTALL_PREFIX)/libexec
THINKCLI_HOME ?= $(LIBEXECDIR)/think

.DEFAULT_GOAL := help

build: lint
	@echo "🔨 Building ThinkCLI..."
	@swift build $(SWIFT_BUILD_FLAGS)
	@echo "✅ ThinkCLI build complete"

build-release:
	@$(MAKE) build CONFIGURATION=release

test: build
	@echo "🧪 Testing ThinkCLI..."
	@swift test $(SWIFT_TEST_FLAGS) --filter ThinkCLITests
	@echo "✅ ThinkCLI tests complete"

run: build
	@echo "🚀 Running ThinkCLI..."
	@swift run $(SWIFT_BUILD_FLAGS) think $(ARGS)

install: build-release
	@echo "📦 Installing ThinkCLI..."
	@echo "  bin:     $(BINDIR)/think"
	@echo "  libexec: $(THINKCLI_HOME)"
	@mkdir -p "$(BINDIR)" "$(THINKCLI_HOME)" "$(THINKCLI_HOME)/Frameworks"
	@install -m 0755 .build/release/think "$(THINKCLI_HOME)/think"
	@# Copy any SwiftPM-built embedded frameworks next to the binary.
	@for fw in .build/release/*.framework; do \
		if [ -d "$$fw" ]; then \
			cp -R "$$fw" "$(THINKCLI_HOME)/Frameworks/"; \
		fi; \
	done
	@{ \
		echo '#!/usr/bin/env bash'; \
		echo 'set -euo pipefail'; \
		echo ''; \
		echo 'BIN_DIR="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" && pwd)"'; \
		echo 'PREFIX="$$(cd "$$BIN_DIR/.." && pwd)"'; \
		echo 'HOME_DIR="$$PREFIX/libexec/think"'; \
		echo 'FRAMEWORKS_DIR="$$HOME_DIR/Frameworks"'; \
		echo ''; \
		echo 'export DYLD_FRAMEWORK_PATH="$$FRAMEWORKS_DIR$${DYLD_FRAMEWORK_PATH:+:$$DYLD_FRAMEWORK_PATH}"'; \
		echo 'export DYLD_LIBRARY_PATH="$$FRAMEWORKS_DIR$${DYLD_LIBRARY_PATH:+:$$DYLD_LIBRARY_PATH}"'; \
		echo ''; \
		echo 'exec "$$HOME_DIR/think" "$$@"'; \
	} >"$(BINDIR)/think"
	@chmod +x "$(BINDIR)/think"
	@echo "✅ Installed: $(BINDIR)/think"

uninstall:
	@echo "🗑️  Uninstalling ThinkCLI..."
	@rm -f "$(BINDIR)/think"
	@rm -rf "$(THINKCLI_HOME)"
	@echo "✅ Uninstalled: $(BINDIR)/think"

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
	@echo "  make build-release - Build ThinkCLI in release mode"
	@echo "  make test        - Run ThinkCLI tests"
	@echo "  make run         - Run ThinkCLI (pass ARGS=...)"
	@echo "  make install     - Install think into $(BINDIR) (override with BINDIR=...)"
	@echo "  make uninstall   - Remove $(BINDIR)/think"
	@echo "  make clean       - Clean build artifacts"

.PHONY: build build-release test run install uninstall lint lint-fix clean help
