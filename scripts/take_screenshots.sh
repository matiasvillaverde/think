#!/bin/bash
#
# Production-ready script for taking and organizing screenshots in both light and dark mode
#

set -e
trap 'echo "Error occurred at line $LINENO: $BASH_COMMAND" >&2' ERR

# ===== CONFIGURATION =====
SCHEME_NAME="Screenshots"
SCREENSHOTS_DIR="./screenshots-localized"
XCRESULT_DIR="$SCREENSHOTS_DIR/xcresults"
LOG_DIR="/tmp/screenshot_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/screenshot_script_${TIMESTAMP}.log"
TIMEOUT_SECONDS=900  # 15 minutes timeout for each test run

# Check if workspace exists and use it, otherwise fall back to project
if [ -d "./Think.xcworkspace" ]; then
    WORKSPACE_PATH="./Think.xcworkspace"
    BUILD_CMD="xcodebuild test -workspace \"$WORKSPACE_PATH\""
else
    PROJECT_PATH="./Think.xcodeproj"
    BUILD_CMD="xcodebuild test -project \"$PROJECT_PATH\""
fi

# List of devices and their UDIDs
SIMULATORS=(
    "iPhone 16 Pro Max:1564C28E-D7DF-4FA2-BE2C-280EAF3EA695"
    "iPhone 14 Plus:B363CDCC-6F8E-4952-95FC-CB0FBA2D94C7"
    "iPad Pro 13-inch (M4):E108DBA3-BC11-4C43-A5AD-27B2BD67EE05"
    "iPad Pro 12.9-inch (6th generation):742C2B64-5AD1-442D-8BE3-AA20E97DE54A"
)

# Validate configuration
if [ -z "$SCHEME_NAME" ]; then
    echo "❌ ERROR: SCHEME_NAME is not set" | tee -a "$LOG_FILE"
    exit 1
fi

# Create directories with error checking
mkdir -p "$SCREENSHOTS_DIR" || { echo "❌ ERROR: Could not create $SCREENSHOTS_DIR"; exit 1; }
mkdir -p "$LOG_DIR" || { echo "❌ ERROR: Could not create $LOG_DIR"; exit 1; }
mkdir -p "$XCRESULT_DIR" || { echo "❌ ERROR: Could not create $XCRESULT_DIR"; exit 1; }

# Check if required tools are available
for tool in xcrun xcodebuild xcparse; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "❌ ERROR: Required tool '$tool' is not installed or not in PATH" | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Start logging
echo "===============================================" | tee -a "$LOG_FILE"
echo "Screenshot script started at $(date)" | tee -a "$LOG_FILE"
echo "Using build command: $BUILD_CMD" | tee -a "$LOG_FILE"
echo "Screenshots will be saved to: $SCREENSHOTS_DIR" | tee -a "$LOG_FILE"
echo "XCResults will be saved to: $XCRESULT_DIR" | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

# Simple function to clean device name for filenames
clean_device_name() {
    echo "$1" | tr -d ':' | tr ' ' '_'
}

# Process screenshots from a test result
process_screenshots() {
    local device="$1"
    local xcresult_path="$2"
    local output_dir="$3"
    local appearance="$4"  # Parameter to track what appearance mode was used
    
    echo "Processing screenshots for $device from $xcresult_path" | tee -a "$LOG_FILE"
    
    # Verify xcresult exists
    if [ ! -d "$xcresult_path" ]; then
        echo "❌ ERROR: XCResult path does not exist: $xcresult_path" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$output_dir" || { 
        echo "❌ ERROR: Could not create output directory $output_dir" | tee -a "$LOG_FILE"
        return 1
    }
    
    # Extract screenshots using xcparse
    if ! xcparse screenshots "$xcresult_path" "$output_dir" >> "$LOG_FILE" 2>&1; then
        echo "⚠️ Failed to extract screenshots from $xcresult_path" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Count extracted screenshots
    local count=$(find "$output_dir" -name "*.png" | wc -l | tr -d ' ')
    echo "Found $count screenshots for $device" | tee -a "$LOG_FILE"
    
    if [ "$count" -eq 0 ]; then
        echo "⚠️ No screenshots found in $xcresult_path" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Process each screenshot PNG file
    find "$output_dir" -name "*.png" | sort | while read -r file; do
        local filename=$(basename "$file")
        echo "Processing file: $filename" | tee -a "$LOG_FILE"
        
        # For filenames in format: language_theme_deviceName_screen_number_UUID.png
        # First, extract the basic parts
        local language=$(echo "$filename" | cut -d'_' -f1)
        local theme=$(echo "$filename" | cut -d'_' -f2)
        local device_in_file=$(echo "$filename" | cut -d'_' -f3)
        
        # Extract the screen name (fourth segment) without the numeric ID and UUID
        local screen=$(echo "$filename" | cut -d'_' -f4)
        
        echo "Extracted: Language=$language, Theme=$theme, Device=$device_in_file, Screen=$screen" | tee -a "$LOG_FILE"
        
        # Validate theme with appearance mode for better consistency
        # If the theme in the filename doesn't match our appearance setting, log a warning
        if [[ "$appearance" == "light" && "$theme" != "light"* ]] || [[ "$appearance" == "dark" && "$theme" != "dark"* ]]; then
            echo "⚠️ WARNING: Theme in filename ($theme) doesn't match appearance setting ($appearance)" | tee -a "$LOG_FILE"
        fi
        
        # Create language directory
        local lang_dir="$SCREENSHOTS_DIR/$language"
        mkdir -p "$lang_dir" || {
            echo "❌ ERROR: Could not create language directory $lang_dir" | tee -a "$LOG_FILE" 
            continue
        }
        
        # Create new filename using the device from the parameter and dropping the ID and UUID
        local new_filename="${device}_${theme}_${screen}.png"
        
        # Check if destination file already exists
        if [ -f "$lang_dir/$new_filename" ]; then
            echo "⚠️ WARNING: File already exists, renaming to avoid overwrite: $lang_dir/$new_filename" | tee -a "$LOG_FILE"
            new_filename="${device}_${theme}_${screen}_${TIMESTAMP}.png"
        fi
        
        # Copy file to final destination
        if cp "$file" "$lang_dir/$new_filename"; then
            echo "✓ Saved: $lang_dir/$new_filename" | tee -a "$LOG_FILE"
        else
            echo "❌ ERROR: Failed to copy file to $lang_dir/$new_filename" | tee -a "$LOG_FILE"
        fi
    done
    
    return 0
}

# Cleanup any stale simulators and temporary files
cleanup() {
    # Shutdown all running simulators
    echo "Shutting down all running simulators..." | tee -a "$LOG_FILE"
    xcrun simctl shutdown all >> "$LOG_FILE" 2>&1 || true
    
    # Kill any hanging simulator processes
    pkill -9 -f Simulator >/dev/null 2>&1 || true
    
    # Remove temporary directories older than 1 day
    find /tmp -name "*_screenshots_*" -type d -mtime +1 -exec rm -rf {} \; 2>/dev/null || true
}

# Run cleanup on script exit
trap cleanup EXIT

# Initial cleanup
cleanup

# # Process macOS
# echo "[$(date +"%H:%M:%S")] Processing macOS..." | tee -a "$LOG_FILE"
# mac_xcresult="$XCRESULT_DIR/TestResults-Mac-$TIMESTAMP.xcresult"
# mac_output_dir="/tmp/mac_screenshots_$TIMESTAMP"
# mkdir -p "$mac_output_dir"

# # Run macOS tests with timeout
# echo "Running macOS tests..." | tee -a "$LOG_FILE"
# if ! timeout $TIMEOUT_SECONDS bash -c "eval \"$BUILD_CMD -scheme \\\"$SCHEME_NAME\\\" -destination 'platform=macOS' -resultBundlePath \\\"$mac_xcresult\\\"\"" >> "$LOG_FILE" 2>&1; then
#     if [ $? -eq 124 ]; then
#         echo "❌ ERROR: macOS tests timed out after $TIMEOUT_SECONDS seconds" | tee -a "$LOG_FILE"
#     else
#         echo "⚠️ macOS tests completed with errors (continuing anyway)" | tee -a "$LOG_FILE"
#     fi
# else
#     echo "✅ macOS tests completed successfully" | tee -a "$LOG_FILE"
# fi

# # Process macOS screenshots
# if [ -d "$mac_xcresult" ]; then
#     echo "Found xcresult: $mac_xcresult" | tee -a "$LOG_FILE"
#     process_screenshots "Mac" "$mac_xcresult" "$mac_output_dir" "system"
#     rm -rf "$mac_output_dir"
# else
#     echo "⚠️ No xcresult found for macOS at $mac_xcresult" | tee -a "$LOG_FILE"
# fi

# Function to process a simulator for a specific appearance mode
process_simulator_mode() {
    local simulator_info="$1"
    local appearance="$2" # 'light' or 'dark'
    
    # Get simulator name and UDID
    local simulator_name=$(echo "$simulator_info" | cut -d':' -f1)
    local simulator_udid=$(echo "$simulator_info" | cut -d':' -f2)
    local clean_name=$(clean_device_name "$simulator_name")
    
    echo "[$(date +"%H:%M:%S")] Processing $simulator_name in $appearance mode..." | tee -a "$LOG_FILE"
    
    # Check if simulator exists
    if ! xcrun simctl list devices | grep -q "$simulator_udid"; then
        echo "❌ ERROR: Simulator $simulator_name with UDID $simulator_udid not found" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Erase the device to start clean
    echo "Erasing simulator $simulator_name..." | tee -a "$LOG_FILE"
    if ! xcrun simctl erase "$simulator_udid" >> "$LOG_FILE" 2>&1; then
        echo "❌ ERROR: Failed to erase simulator $simulator_name" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Boot simulator
    echo "Booting simulator $simulator_name..." | tee -a "$LOG_FILE"
    if ! xcrun simctl boot "$simulator_udid" >> "$LOG_FILE" 2>&1; then
        echo "❌ ERROR: Failed to boot simulator $simulator_name" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Wait for simulator to fully boot
    echo "Waiting for simulator to fully boot (15s)..." | tee -a "$LOG_FILE"
    sleep 15
    
    # Verify simulator is ready
    if ! xcrun simctl list devices | grep "$simulator_udid" | grep -q "Booted"; then
        echo "❌ ERROR: Simulator did not reach Booted state" | tee -a "$LOG_FILE"
        xcrun simctl shutdown "$simulator_udid" >> "$LOG_FILE" 2>&1 || true
        return 1
    fi
    
    # Set appearance mode for dark mode only
    if [ "$appearance" = "dark" ]; then
        echo "Setting simulator appearance to dark..." | tee -a "$LOG_FILE"
        # Try up to 3 times to set appearance
        local retry_count=0
        local max_retries=3
        local success=false
        
        while [ $retry_count -lt $max_retries ] && [ "$success" != "true" ]; do
            if xcrun simctl ui "$simulator_udid" appearance dark >> "$LOG_FILE" 2>&1; then
                echo "✅ Successfully set appearance to dark on attempt $((retry_count+1))" | tee -a "$LOG_FILE"
                success=true
            else
                retry_count=$((retry_count+1))
                echo "⚠️ Failed to set appearance on attempt $retry_count, retrying in 5s..." | tee -a "$LOG_FILE"
                sleep 5
            fi
        done
        
        if [ "$success" != "true" ]; then
            echo "❌ ERROR: Failed to set appearance mode to dark after $max_retries attempts" | tee -a "$LOG_FILE"
            xcrun simctl shutdown "$simulator_udid" >> "$LOG_FILE" 2>&1 || true
            return 1
        fi
    fi
    
    # Configure status bar
    echo "Setting simulator status bar..." | tee -a "$LOG_FILE"
    xcrun simctl status_bar "$simulator_udid" override \
        --time '9:41' \
        --dataNetwork wifi \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --operatorName '' \
        --cellularBars 4 \
        --batteryState charged \
        --batteryLevel 100 >> "$LOG_FILE" 2>&1
    
    # Setup paths for this run
    local sim_xcresult="$XCRESULT_DIR/TestResults-${clean_name}-${appearance}-${TIMESTAMP}.xcresult"
    local sim_output_dir="/tmp/${clean_name}_${appearance}_screenshots_${TIMESTAMP}"
    mkdir -p "$sim_output_dir"
    
    # Run tests with timeout
    echo "Running tests on $simulator_name in $appearance mode..." | tee -a "$LOG_FILE"
    if ! timeout $TIMEOUT_SECONDS bash -c "eval \"$BUILD_CMD -scheme \\\"$SCHEME_NAME\\\" -destination 'platform=iOS Simulator,id=$simulator_udid' -resultBundlePath \\\"$sim_xcresult\\\"\"" >> "$LOG_FILE" 2>&1; then
        if [ $? -eq 124 ]; then
            echo "❌ ERROR: Tests timed out after $TIMEOUT_SECONDS seconds" | tee -a "$LOG_FILE"
        else
            echo "⚠️ Tests completed with errors (continuing anyway)" | tee -a "$LOG_FILE"
        fi
    else
        echo "✅ Tests completed successfully" | tee -a "$LOG_FILE"
    fi
    
    # Process screenshots if xcresult exists
    if [ -d "$sim_xcresult" ]; then
        echo "Found xcresult: $sim_xcresult" | tee -a "$LOG_FILE"
        process_screenshots "$simulator_name" "$sim_xcresult" "$sim_output_dir" "$appearance"
        rm -rf "$sim_output_dir"
    else
        echo "⚠️ No xcresult found for $simulator_name at $sim_xcresult" | tee -a "$LOG_FILE"
    fi
    
    # Shutdown simulator
    echo "Shutting down simulator $simulator_name..." | tee -a "$LOG_FILE"
    xcrun simctl shutdown "$simulator_udid" >> "$LOG_FILE" 2>&1 || true
    
    echo "✅ Completed processing for $simulator_name in $appearance mode" | tee -a "$LOG_FILE"
    return 0
}

# Process all simulators in light mode first
echo "===============================================" | tee -a "$LOG_FILE"
echo "Processing iOS simulators in LIGHT mode..." | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

for simulator_info in "${SIMULATORS[@]}"; do
    simulator_name=$(echo "$simulator_info" | cut -d':' -f1)
    echo "[$(date +"%H:%M:%S")] Starting LIGHT mode test sequence for $simulator_name..." | tee -a "$LOG_FILE"
    
    # Process simulator in light mode (default appearance)
    if ! process_simulator_mode "$simulator_info" "light"; then
        echo "⚠️ Failed to process $simulator_name in light mode, continuing with next device" | tee -a "$LOG_FILE"
    fi
    
    # Ensure simulator is fully shut down before next run
    sleep 5
done

# Process all simulators in dark mode
echo "===============================================" | tee -a "$LOG_FILE"
echo "Processing iOS simulators in DARK mode..." | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

for simulator_info in "${SIMULATORS[@]}"; do
    simulator_name=$(echo "$simulator_info" | cut -d':' -f1)
    echo "[$(date +"%H:%M:%S")] Starting DARK mode test sequence for $simulator_name..." | tee -a "$LOG_FILE"
    
    # Process simulator in dark mode
    if ! process_simulator_mode "$simulator_info" "dark"; then
        echo "⚠️ Failed to process $simulator_name in dark mode, continuing with next device" | tee -a "$LOG_FILE"
    fi
    
    # Ensure simulator is fully shut down before next run
    sleep 5
done

# Generate final report
echo "===============================================" | tee -a "$LOG_FILE"
echo "Screenshot generation completed at $(date)" | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

echo "Screenshot counts by device:" | tee -a "$LOG_FILE"
for simulator_info in "${SIMULATORS[@]}"; do
    simulator_name=$(echo "$simulator_info" | cut -d':' -f1)
    light_count=$(find "$SCREENSHOTS_DIR" -name "${simulator_name}_light*.png" | wc -l | tr -d ' ')
    dark_count=$(find "$SCREENSHOTS_DIR" -name "${simulator_name}_dark*.png" | wc -l | tr -d ' ')
    total_count=$((light_count + dark_count))
    echo "$simulator_name: $total_count total ($light_count light, $dark_count dark)" | tee -a "$LOG_FILE"
done

mac_count=$(find "$SCREENSHOTS_DIR" -name "Mac_*.png" | wc -l | tr -d ' ')
echo "Mac: $mac_count" | tee -a "$LOG_FILE"

total=$(find "$SCREENSHOTS_DIR" -type f -name "*.png" | wc -l | tr -d ' ')
echo "Total screenshots: $total" | tee -a "$LOG_FILE"

if [ "$total" -gt 0 ]; then
    echo "✅ SUCCESS: Generated $total screenshots" | tee -a "$LOG_FILE"
else
    echo "⚠️ WARNING: No screenshots were generated" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Screenshot generation complete. Log file: $LOG_FILE"
exit 0