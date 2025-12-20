#!/bin/bash
# Setup git hooks for Think project

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "🔧 Setting up git hooks for Think project..."

# Check if we're in a git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Error: Not in a git repository. Please run this from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for Think project
# Builds modified modules (which includes linting) before allowing commit

set -e

echo "🎯 Running pre-commit checks..."

# List of all modules
MODULES="Abstractions AudioGenerator Context Database Factories ImageGenerator LLamaCPP ModelDownloader AgentOrchestrator MLXSession RAG UIComponents ViewModels AppStoreConnectCLI"

# Track if any tests were run
tests_run=false

# Check each module for changes
for module in $MODULES; do
    if git diff --cached --name-only | grep -q "^$module/"; then
        echo "📦 $module changes detected..."
        
        # Change to module directory and run build (which includes lint)
        cd "$module"
        
        echo "🔨 Building $module (includes linting)..."
        if ! make build; then
            echo "❌ $module build failed. Please fix build/lint issues before committing."
            echo "💡 Tip: Run 'cd $module && make lint' to see lint issues"
            echo "💡 Tip: Run 'cd $module && make lint-fix' to auto-fix lint issues"
            cd ..
            exit 1
        fi
        
        cd ..
        tests_run=true
    fi
done

# Check if Think app files were modified
if git diff --cached --name-only | grep -q "^Think/"; then
    echo "🦜 Think app changes detected, running lint checks..."
    
    # Run Think linting
    cd Think && if ! swiftlint --strict --quiet .; then
        echo "❌ Think linting failed. Please fix lint issues before committing."
        cd ..
        exit 1
    else
        echo "✅ Think linted successfully"
    fi
    cd ..
    tests_run=true
fi

# Check if ThinkVision app files were modified
if git diff --cached --name-only | grep -q "^Think Vision/"; then
    echo "🥽 ThinkVision app changes detected, running lint checks..."
    
    # Run ThinkVision linting
    cd "Think Vision" && if ! swiftlint --strict --quiet .; then
        echo "❌ ThinkVision linting failed. Please fix lint issues before committing."
        cd ..
        exit 1
    else
        echo "✅ ThinkVision linted successfully"
    fi
    cd ..
    tests_run=true
fi

if [ "$tests_run" = true ]; then
    echo "✅ Pre-commit checks passed!"
else
    echo "ℹ️  No relevant changes detected in modules or apps."
fi

exit 0
EOF

# Pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook for Think project
# Runs tests (which includes build and lint) for modified modules before pushing

set -e

echo "🚀 Running pre-push checks..."

# List of all modules
MODULES="Abstractions AudioGenerator Context Database Factories ImageGenerator LLamaCPP ModelDownloader AgentOrchestrator MLXSession RAG UIComponents ViewModels AppStoreConnectCLI"

# Get commits being pushed
commits=$(git rev-list @{u}..)

# Track which modules changed (using simple string concatenation instead of associative array)
changed_modules=""

# Check each commit for changes
for commit in $commits; do
    for module in $MODULES; do
        if git diff-tree --no-commit-id --name-only -r $commit | grep -q "^$module/"; then
            # Add to changed modules if not already there
            if ! echo "$changed_modules" | grep -q " $module "; then
                changed_modules="$changed_modules $module "
            fi
        fi
    done
    
    # Check app changes
    if git diff-tree --no-commit-id --name-only -r $commit | grep -q "^Think/"; then
        if ! echo "$changed_modules" | grep -q " Think "; then
            changed_modules="$changed_modules Think "
        fi
    fi
    
    if git diff-tree --no-commit-id --name-only -r $commit | grep -q "^Think Vision/"; then
        if ! echo "$changed_modules" | grep -q " ThinkVision "; then
            changed_modules="$changed_modules ThinkVision "
        fi
    fi
done

# Test changed modules
for module in $MODULES; do
    if echo "$changed_modules" | grep -q " $module "; then
        echo "📦 $module changes detected in push..."
        
        cd "$module"
        
        # Run tests (which includes build and lint)
        echo "🧪 Running $module tests (includes build & lint)..."
        if ! make test; then
            echo "❌ $module tests failed. Please fix before pushing."
            cd ..
            exit 1
        fi
        
        # Run acceptance tests if requested and available
        if [ -n "$RUN_ACCEPTANCE_TESTS" ] && make help | grep -q "test-acceptance"; then
            echo "🌐 Running $module acceptance tests..."
            if ! make test-acceptance; then
                echo "❌ $module acceptance tests failed."
                cd ..
                exit 1
            fi
        fi
        
        cd ..
    fi
done

# Check app linting
if echo "$changed_modules" | grep -q " Think "; then
    echo "🦜 Think app changes detected in push, running lint checks..."
    
    cd Think && if ! swiftlint --strict --quiet .; then
        echo "❌ Think linting failed. Please fix before pushing."
        cd ..
        exit 1
    else
        echo "✅ Think linted successfully"
    fi
    cd ..
fi

if echo "$changed_modules" | grep -q " ThinkVision "; then
    echo "🥽 ThinkVision app changes detected in push, running lint checks..."
    
    cd "Think Vision" && if ! swiftlint --strict --quiet .; then
        echo "❌ ThinkVision linting failed. Please fix before pushing."
        cd ..
        exit 1
    else
        echo "✅ ThinkVision linted successfully"
    fi
    cd ..
fi

echo "✅ Pre-push checks passed!"
echo "📤 Pushing to remote repository..."
exit 0
EOF

# Make hooks executable
chmod +x "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Git hooks installed successfully!"
echo ""
echo "📋 Installed hooks:"
echo "  - pre-commit: Builds modified modules (includes linting)"
echo "  - pre-push: Runs tests for modified modules (includes build & lint)"
echo ""
echo "💡 Tips:"
echo "  - To skip hooks temporarily, use: git commit --no-verify or git push --no-verify"
echo "  - To run acceptance tests on push: RUN_ACCEPTANCE_TESTS=1 git push"
echo "  - To uninstall hooks: rm .git/hooks/pre-{commit,push}"
echo "  - DO NOT use --no-verify, especially for pre-push hooks!"
echo ""
echo "🎉 Setup complete!"