#!/bin/bash
# Test filter script - Shows only failed tests and summary
# Usage: swift test | ./scripts/test-filter.sh [MODULE_NAME]

set -euo pipefail

MODULE_NAME="${1:-Module}"
TEMP_FILE=$(mktemp)
FAILED_TESTS=()
TOTAL_TESTS=0
FAILED_COUNT=0

# Read all input into temp file
cat > "$TEMP_FILE"

# Parse test results
while IFS= read -r line; do
    # Count total tests
    if [[ "$line" =~ Test\ Case.*started ]]; then
        ((TOTAL_TESTS++))
    fi
    
    # Capture failed tests
    if [[ "$line" =~ Test\ Case.*failed|error:|Error:|FAIL ]]; then
        FAILED_TESTS+=("$line")
        ((FAILED_COUNT++))
    fi
    
    # Also capture any lines that show failure details
    if [[ "$line" =~ XCTAssert|failed\ assertion|Test\ failed ]]; then
        FAILED_TESTS+=("$line")
    fi
done < "$TEMP_FILE"

# Display results
echo "🧪 Testing $MODULE_NAME..."

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo "❌ Failed tests:"
    printf '%s\n' "${FAILED_TESTS[@]}"
    echo ""
    echo "❌ $MODULE_NAME: $FAILED_COUNT test(s) failed out of $TOTAL_TESTS"
    exit 1
else
    echo "✅ $MODULE_NAME: All tests passed ($TOTAL_TESTS tests)"
fi

# Cleanup
rm -f "$TEMP_FILE"