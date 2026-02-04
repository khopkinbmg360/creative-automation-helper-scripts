#!/bin/bash

# ============================================
# VIDEO TEXT OVERLAY SCRIPT (CSV-Driven)
# ============================================
#
# DESCRIPTION:
#   This script adds text overlays to videos with customizable timing, positioning,
#   and effects. It supports three modes: single file, batch processing, and CSV-driven
#   batch processing with individual settings per video.
#
# FEATURES:
#   - CSV-driven batch processing with per-video customization
#   - Dynamic text positioning (top, center, bottom, left, right)
#   - Text effects: fade in/out, slide animation, drop shadow, outline/border
#   - Multi-line text support with configurable line spacing
#   - Auto-detection of video dimensions
#   - Support for both portrait and landscape videos
#   - Handles .mp4 and .mov files
#
# USAGE:
#
#   Single File Mode:
#     ./add_text_csv.sh
#     (Edit INPUT_VIDEO, OUTPUT_VIDEO, TEXT, START_TIME, END_TIME in script)
#
#   Batch Mode (all videos in directory with same text):
#     Set BATCH_MODE=true in script
#     ./add_text_csv.sh
#
#   CSV Mode (different text/timing per video):
#     ./add_text_csv.sh --csv videos.csv --output-dir ./output
#
# CSV FORMAT:
#   Required columns:
#     - filename: Path to video file (can be relative)
#     - START_TIME: When text appears (in seconds)
#     - END_TIME: When text disappears (in seconds)
#     - TEXT: Text to display (use \n for line breaks)
#
#   Optional columns:
#     - VIDEO_WIDTH: Override default video width
#     - VIDEO_HEIGHT: Override default video height
#     - FILENAME_OUTPUT: Custom output filename (with or without extension)
#                        Extension auto-added if not provided
#                        If empty, uses default: original_name_text.mp4
#
#   Example CSV:
#     filename,START_TIME,END_TIME,TEXT,FILENAME_OUTPUT
#     videos/clip1.mp4,2,10,Hello\nWorld,custom1
#     videos/clip2.mp4,3,8,Welcome,final_output.mp4
#
# COMMAND LINE OPTIONS:
#   --csv FILE         Path to CSV file for batch processing
#   --base-path PATH   Optional path to prepend to filenames in CSV
#   --output-dir DIR   Output directory (default: ./output)
#   --dry-run          List files that would be processed without processing them
#   --help             Show help message
#
# CONFIGURATION:
#   All settings can be configured in the "Configuration" section below:
#   - Video dimensions (VIDEO_WIDTH, VIDEO_HEIGHT)
#   - Font settings (file, size, color, opacity)
#   - Text positioning (margins, alignment)
#   - Visual effects (shadow, border, fade, slide)
#   - Timing (start/end times for non-CSV mode)
#
# EXAMPLES:
#
#   1. Process CSV with videos in current directory:
#      ./add_text_csv.sh --csv videos.csv --output-dir ./output
#
#   2. Process CSV with videos in subdirectory:
#      ./add_text_csv.sh --csv videos.csv --base-path ./input --output-dir ./output
#
#   3. Dry run to preview what will be processed:
#      ./add_text_csv.sh --csv videos.csv --dry-run
#
#   4. Single video with custom text:
#      Edit TEXT, START_TIME, END_TIME in script, then run:
#      ./add_text_csv.sh
#
# REQUIREMENTS:
#   - ffmpeg (for video processing)
#   - ffprobe (for dimension detection, optional but recommended)
#   - bash 4.0 or later
#   - bc (for fade calculations)
#
# NOTES:
#   - Line breaks in CSV: Use literal \n (will be converted automatically)
#   - Windows line endings: Automatically handled (CR/LF)
#   - Text opacity: Use TEXT_OPACITY or fade effect, not both
#   - Font files: Place .ttf font files in same directory as script
#
# ============================================

# ============================================
# CONFIGURATION
# ============================================

# Processing Mode
# ---------------
# CSV_MODE: Use CSV file for batch processing (set via --csv flag)
# BATCH_MODE: Process all videos in INPUT_DIRECTORY with same text
# DRY_RUN: If true, only show what would be processed without actually processing
# VERBOSE: If true, show detailed output; if false, show minimal progress
CSV_MODE=false
BATCH_MODE=false
DRY_RUN=false
VERBOSE=false

# CSV Configuration
# ----------------
# CSV_FILE: Path to CSV file (override with --csv flag)
# CSV_BASE_PATH: Optional base path to prepend to filenames in CSV
CSV_FILE=""
CSV_BASE_PATH=""

# Input/Output Files (Single File Mode)
# -------------------------------------
# INPUT_VIDEO: Source video file path
# OUTPUT_VIDEO: Destination video file path
INPUT_VIDEO="input.mp4"
OUTPUT_VIDEO="testoutput.mp4"

# Batch Processing Settings
# -------------------------
# INPUT_DIRECTORY: Folder containing mp4/mov files (BATCH_MODE only)
# OUTPUT_DIRECTORY: Where processed videos are saved
# OUTPUT_SUFFIX: Text appended to filename (e.g., video.mp4 -> video_text.mp4)
INPUT_DIRECTORY="./input"
OUTPUT_DIRECTORY="./output"
OUTPUT_SUFFIX="_text"

# Video Dimensions
# ---------------
# VIDEO_WIDTH: Default video width in pixels
# VIDEO_HEIGHT: Default video height in pixels
# Note: Auto-detected if ffprobe is available, or override via CSV columns
VIDEO_WIDTH=1080
VIDEO_HEIGHT=1350

# Font Settings
# ------------
# FONT_FILE: Path to TrueType font file (.ttf)
# FONT_SIZE: Font size in points
# FONT_COLOR: Color name or hex code (e.g., "white", "#FFFFFF")
# TEXT_OPACITY: Text opacity from 0.0 (transparent) to 1.0 (opaque)
FONT_FILE="Arial.ttf"
FONT_SIZE=30
FONT_COLOR="white"
TEXT_OPACITY=1.0

# Text Content (Non-CSV Mode Only)
# --------------------------------
# TEXT: Text to display on video
# Use $'...' syntax for line breaks: TEXT=$'Line 1\nLine 2\nLine 3'
TEXT=$'*Interest accrues from purchase date\nbut is waived if paid in full within X months'

# Timing (Non-CSV Mode Only)
# --------------------------
# START_TIME: When text appears (in seconds)
# END_TIME: When text disappears (in seconds)
START_TIME=2
END_TIME=10

# Text Position Settings
# ---------------------
# BOTTOM_MARGIN: Distance from bottom of video (in pixels)
# TEXT_ALIGNMENT: Horizontal alignment - "left", "center", or "right"
# LEFT_MARGIN: Distance from left edge when TEXT_ALIGNMENT="left"
BOTTOM_MARGIN=250
TEXT_ALIGNMENT="center"
LEFT_MARGIN=50

# Line Spacing (Multi-line Text)
# ------------------------------
# LINE_SPACING: Space between lines (1.0 = tight, 1.5 = loose)
# TEXT_BLOCK_ALIGNMENT: How multi-line text aligns - "left", "center", "right"
LINE_SPACING=0.7
TEXT_BLOCK_ALIGNMENT="center"

# Background Box (Optional)
# ------------------------
# ENABLE_BOX: Set to "true" to add background box behind text
# BOX_COLOR: Box color with optional transparency (e.g., "black@0.5")
# BOX_BORDER: Padding around text in pixels
ENABLE_BOX=false
BOX_COLOR="black@0.5"
BOX_BORDER=10

# Drop Shadow (Optional)
# ---------------------
# ENABLE_SHADOW: Set to "true" to add drop shadow
# SHADOW_X: Horizontal shadow offset (positive=right, negative=left)
# SHADOW_Y: Vertical shadow offset (positive=down, negative=up)
# SHADOW_COLOR: Shadow color with optional transparency
ENABLE_SHADOW=false
SHADOW_X=4
SHADOW_Y=4
SHADOW_COLOR="black"

# Text Outline/Border (Optional)
# ------------------------------
# ENABLE_BORDER: Set to "true" to add text outline
# BORDER_WIDTH: Border thickness in pixels (typically 1-5)
# BORDER_COLOR: Border color with optional transparency
ENABLE_BORDER=true
BORDER_WIDTH=3
BORDER_COLOR="black"

# Animation/Effects
# ----------------
# EFFECT_TYPE: Animation type - "none", "slide", or "fade"
#   "none": Text appears/disappears instantly
#   "slide": Text slides in from left
#   "fade": Text fades in and out smoothly
# ANIMATION_SPEED: Speed for slide effect (pixels per second)
# FADE_DURATION: Fade in/out duration in seconds
EFFECT_TYPE="fade"
ANIMATION_SPEED=250
FADE_DURATION=0.5

# Output Duration (Optional)
# --------------------------
# OUTPUT_DURATION: Trim output video to this length (in seconds)
# Leave empty "" to keep original video length
OUTPUT_DURATION=""

# ============================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --csv)
            CSV_FILE="$2"
            CSV_MODE=true
            shift 2
            ;;
        --base-path)
            CSV_BASE_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIRECTORY="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift 1
            ;;
        --verbose)
            VERBOSE=true
            shift 1
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --csv FILE         Use CSV file for batch processing"
            echo "  --base-path PATH   (Optional) Base path to prepend to filenames in CSV"
            echo "  --output-dir DIR   Output directory for processed videos (default: ./output)"
            echo "  --dry-run          Show what would be processed without actually processing"
            echo "  --verbose          Show detailed output (default: minimal progress)"
            echo "  --help             Show this help message"
            echo ""
            echo "CSV Format:"
            echo "  Required columns: filename, START_TIME, END_TIME, TEXT"
            echo "  Optional columns: VIDEO_WIDTH, VIDEO_HEIGHT, FILENAME_OUTPUT"
            echo "  The 'filename' column should contain the path to each video file"
            echo "  The 'FILENAME_OUTPUT' can be with or without extension"
            echo "  Use \\n in TEXT column for line breaks"
            echo ""
            echo "Example 1 (CSV with full paths):"
            echo "  $0 --csv videos.csv --output-dir ./output"
            echo ""
            echo "Example 2 (CSV with relative filenames, prepend base path):"
            echo "  $0 --csv videos.csv --base-path ./input --output-dir ./output"
            echo ""
            echo "Example 3 (Dry run to see what would be processed):"
            echo "  $0 --csv videos.csv --dry-run"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ============================================
# PROCESSING FUNCTIONS
# ============================================

# Function to process a single video file with specific text and timing
process_video() {
    local input_file="$1"
    local output_file="$2"
    local video_text="$3"
    local start_time="$4"
    local end_time="$5"
    local csv_width="$6"
    local csv_height="$7"
    local row_number="$8"  # Optional row number for display
    
    if [ "$VERBOSE" = "true" ]; then
        echo "================================"
        echo "Processing: $input_file"
        echo "Output: $output_file"
        echo "Text: $video_text"
        echo "Timing: ${start_time}s - ${end_time}s"
    else
        # Minimal output: just show row number and filename
        if [ -n "$row_number" ]; then
            echo -n "[$row_number] $(basename "$input_file") → $(basename "$output_file") ... "
        else
            echo -n "Processing $(basename "$input_file") ... "
        fi
    fi
    
    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        if [ "$VERBOSE" = "true" ]; then
            echo "✗ Error: Input file not found: $input_file"
            echo ""
        else
            echo "✗ NOT FOUND"
        fi
        return 1
    fi
    
    # Use CSV dimensions if provided, otherwise use defaults
    local CURRENT_WIDTH=$VIDEO_WIDTH
    local CURRENT_HEIGHT=$VIDEO_HEIGHT
    
    if [ -n "$csv_width" ] && [ -n "$csv_height" ]; then
        CURRENT_WIDTH=$csv_width
        CURRENT_HEIGHT=$csv_height
        if [ "$VERBOSE" = "true" ]; then
            echo "Using dimensions from CSV: ${CURRENT_WIDTH}x${CURRENT_HEIGHT}"
        fi
    fi
    
    # Detect actual video dimensions if ffprobe is available (for verification)
    if command -v ffprobe &> /dev/null; then
        DETECTED_WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input_file" 2>/dev/null)
        DETECTED_HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$input_file" 2>/dev/null)
        
        if [ -n "$DETECTED_WIDTH" ] && [ -n "$DETECTED_HEIGHT" ]; then
            if [ "$VERBOSE" = "true" ]; then
                echo "Detected dimensions: ${DETECTED_WIDTH}x${DETECTED_HEIGHT}"
            fi
            # If CSV didn't provide dimensions, use detected ones
            if [ -z "$csv_width" ] || [ -z "$csv_height" ]; then
                if [ "$DETECTED_WIDTH" != "$VIDEO_WIDTH" ] || [ "$DETECTED_HEIGHT" != "$VIDEO_HEIGHT" ]; then
                    if [ "$VERBOSE" = "true" ]; then
                        echo "Using detected dimensions instead of configured (${VIDEO_WIDTH}x${VIDEO_HEIGHT})"
                    fi
                    CURRENT_WIDTH=$DETECTED_WIDTH
                    CURRENT_HEIGHT=$DETECTED_HEIGHT
                fi
            fi
        fi
    fi
    
    # Calculate positions with current dimensions
    local CURRENT_Y_POS=$((CURRENT_HEIGHT - BOTTOM_MARGIN))
    
    # Calculate X position
    local X_POS_BASE
    case "$TEXT_ALIGNMENT" in
        left)
            X_POS_BASE="$LEFT_MARGIN"
            ;;
        center)
            X_POS_BASE="(w-text_w)/2"
            ;;
        right)
            X_POS_BASE="w-text_w-$LEFT_MARGIN"
            ;;
        *)
            X_POS_BASE="(w-text_w)/2"
            ;;
    esac
    
    # Add animation/effect if enabled
    local CURRENT_X_POS
    if [ "$EFFECT_TYPE" = "slide" ]; then
        ANIM_DURATION=1.0
        CURRENT_X_POS="if(lt(t\,${start_time})\,-w\,if(lt(t\,${start_time}+${ANIM_DURATION})\,-w+(${X_POS_BASE}+w)*(t-${start_time})/${ANIM_DURATION}\,${X_POS_BASE}))"
    else
        CURRENT_X_POS="$X_POS_BASE"
    fi
    
    # Build the drawtext filter
    local CURRENT_FILTER="drawtext=fontfile=${FONT_FILE}:text='${video_text}':fontsize=${FONT_SIZE}:fontcolor=${FONT_COLOR}:x=${CURRENT_X_POS}:y=${CURRENT_Y_POS}:line_spacing=${LINE_SPACING}:text_align=${TEXT_BLOCK_ALIGNMENT}"
    
    # Add border/outline if enabled
    if [ "$ENABLE_BORDER" = "true" ]; then
        CURRENT_FILTER="${CURRENT_FILTER}:borderw=${BORDER_WIDTH}:bordercolor=${BORDER_COLOR}"
    fi
    
    # Add shadow if enabled
    if [ "$ENABLE_SHADOW" = "true" ]; then
        CURRENT_FILTER="${CURRENT_FILTER}:shadowx=${SHADOW_X}:shadowy=${SHADOW_Y}:shadowcolor=${SHADOW_COLOR}"
    fi
    
    # Add fade effect if enabled, or apply constant opacity
    if [ "$EFFECT_TYPE" = "fade" ]; then
        FADE_IN_END=$(echo "$start_time + $FADE_DURATION" | bc)
        FADE_OUT_START=$(echo "$end_time - $FADE_DURATION" | bc)
        ALPHA="if(lt(t\,${start_time})\,0\,if(lt(t\,${FADE_IN_END})\,(t-${start_time})/${FADE_DURATION}\,if(lt(t\,${FADE_OUT_START})\,1\,if(lt(t\,${end_time})\,(${end_time}-t)/${FADE_DURATION}\,0))))"
        CURRENT_FILTER="${CURRENT_FILTER}:alpha='${ALPHA}'"
    elif [ "$TEXT_OPACITY" != "1.0" ] && [ "$TEXT_OPACITY" != "1" ]; then
        # Apply constant opacity if not using fade and opacity is not 1.0
        CURRENT_FILTER="${CURRENT_FILTER}:alpha=${TEXT_OPACITY}"
    fi
    
    # Add box if enabled
    if [ "$ENABLE_BOX" = "true" ]; then
        CURRENT_FILTER="${CURRENT_FILTER}:box=1:boxcolor=${BOX_COLOR}:boxborderw=${BOX_BORDER}"
    fi
    
    # Add timing
    CURRENT_FILTER="${CURRENT_FILTER}:enable='between(t,${start_time},${end_time})'"
    
    # Build and execute ffmpeg command
    if [ "$VERBOSE" = "true" ]; then
        # Verbose mode: show everything
        local FFMPEG_CMD="ffmpeg -y -nostdin -i '${input_file}' -vf \"${CURRENT_FILTER}\""
    else
        # Quiet mode: use -loglevel error to hide info, but -stats still shows progress
        local FFMPEG_CMD="ffmpeg -y -nostdin -loglevel error -stats -i '${input_file}' -vf \"${CURRENT_FILTER}\""
    fi
    
    if [ -n "$OUTPUT_DURATION" ]; then
        FFMPEG_CMD="${FFMPEG_CMD} -t ${OUTPUT_DURATION}"
    fi
    
    FFMPEG_CMD="${FFMPEG_CMD} '${output_file}'"
    
    if [ "$VERBOSE" = "true" ]; then
        echo "Command: $FFMPEG_CMD"
        echo "================================"
    fi
    
    eval "$FFMPEG_CMD"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if [ "$VERBOSE" = "true" ]; then
            echo "✓ Success: $output_file"
        else
            # Show elapsed time after success
            if [ -n "$START_TIME_EPOCH" ]; then
                current_time=$(date +%s)
                elapsed=$((current_time - START_TIME_EPOCH))
                hours=$((elapsed / 3600))
                minutes=$(((elapsed % 3600) / 60))
                seconds=$((elapsed % 60))
                printf "✓ [Elapsed: %02d:%02d:%02d]\n" $hours $minutes $seconds
            else
                echo "✓"
            fi
        fi
        return 0
    else
        if [ "$VERBOSE" = "true" ]; then
            echo "✗ Failed: $input_file"
        else
            echo "✗ FAILED"
        fi
        return 1
    fi
    
    if [ "$VERBOSE" = "true" ]; then
        echo ""
    fi
}

# ============================================
# MAIN EXECUTION
# ============================================

if [ "$CSV_MODE" = "true" ]; then
    # Record start time
    START_TIME_EPOCH=$(date +%s)
    START_TIME_DISPLAY=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "================================"
    if [ "$DRY_RUN" = "true" ]; then
        echo "DRY RUN MODE - No files will be processed"
    else
        echo "CSV PROCESSING MODE"
    fi
    echo "================================"
    echo "Started: $START_TIME_DISPLAY"
    echo "CSV file: $CSV_FILE"
    echo "Output directory: $OUTPUT_DIRECTORY"
    if [ -n "$CSV_BASE_PATH" ]; then
        echo "Base path: $CSV_BASE_PATH (will be prepended to filenames)"
    else
        echo "Using paths from CSV as-is"
    fi
    echo ""
    
    # Check if CSV file exists
    if [ ! -f "$CSV_FILE" ]; then
        echo "Error: CSV file not found: $CSV_FILE"
        exit 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIRECTORY"
    
    # Check if CSV file exists
    if [ ! -f "$CSV_FILE" ]; then
        echo "Error: CSV file not found: $CSV_FILE"
        exit 1
    fi
    
    # Read the header line to get column indices
    # Remove carriage returns and read into array
    header_line=$(head -1 "$CSV_FILE" | tr -d '\r')
    IFS=',' read -ra HEADERS <<< "$header_line"
    
    # Find the indices of required columns
    filename_idx=-1
    start_time_idx=-1
    end_time_idx=-1
    text_idx=-1
    # Optional columns
    video_width_idx=-1
    video_height_idx=-1
    filename_output_idx=-1
    
    for i in "${!HEADERS[@]}"; do
        # Trim whitespace from header
        header=$(echo "${HEADERS[$i]}" | xargs)
        
        # Debug output
        # echo "Checking header $i: [$header]"
        
        case "$header" in
            filename)
                filename_idx=$i
                ;;
            START_TIME)
                start_time_idx=$i
                ;;
            END_TIME)
                end_time_idx=$i
                ;;
            TEXT)
                text_idx=$i
                ;;
            VIDEO_WIDTH)
                video_width_idx=$i
                ;;
            VIDEO_HEIGHT)
                video_height_idx=$i
                ;;
            FILENAME_OUTPUT)
                filename_output_idx=$i
                ;;
        esac
    done
    
    # Verify required columns exist
    if [ $filename_idx -eq -1 ] || [ $start_time_idx -eq -1 ] || [ $end_time_idx -eq -1 ] || [ $text_idx -eq -1 ]; then
        echo "Error: CSV must contain columns: filename, START_TIME, END_TIME, TEXT"
        echo "Found column headers:"
        for i in "${!HEADERS[@]}"; do
            header=$(echo "${HEADERS[$i]}" | xargs)
            echo "  Column $((i+1)): [$header]"
        done
        echo ""
        echo "Matched columns:"
        echo "  filename: $filename_idx"
        echo "  START_TIME: $start_time_idx"
        echo "  END_TIME: $end_time_idx"
        echo "  TEXT: $text_idx"
        exit 1
    fi
    
    echo "Column mapping:"
    echo "  filename: column $((filename_idx + 1))"
    echo "  START_TIME: column $((start_time_idx + 1))"
    echo "  END_TIME: column $((end_time_idx + 1))"
    echo "  TEXT: column $((text_idx + 1))"
    if [ $video_width_idx -ne -1 ]; then
        echo "  VIDEO_WIDTH: column $((video_width_idx + 1)) (optional)"
    fi
    if [ $video_height_idx -ne -1 ]; then
        echo "  VIDEO_HEIGHT: column $((video_height_idx + 1)) (optional)"
    fi
    if [ $filename_output_idx -ne -1 ]; then
        echo "  FILENAME_OUTPUT: column $((filename_output_idx + 1)) (optional)"
    fi
    echo ""
    
    # Read CSV file and process each video
    line_number=0
    success_count=0
    fail_count=0
    
    # Use process substitution to avoid subshell issues
    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        
        # Skip header line
        if [ $line_number -eq 1 ]; then
            continue
        fi
        
        # Remove carriage return if present
        line=$(echo "$line" | tr -d '\r')
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Split line by comma using awk to handle fields properly
        filename=$(echo "$line" | awk -F',' -v col=$((filename_idx + 1)) '{print $col}')
        start_time=$(echo "$line" | awk -F',' -v col=$((start_time_idx + 1)) '{print $col}')
        end_time=$(echo "$line" | awk -F',' -v col=$((end_time_idx + 1)) '{print $col}')
        text=$(echo "$line" | awk -F',' -v col=$((text_idx + 1)) '{print $col}')
        
        # Extract optional dimensions if available
        csv_width=""
        csv_height=""
        if [ $video_width_idx -ne -1 ]; then
            csv_width=$(echo "$line" | awk -F',' -v col=$((video_width_idx + 1)) '{print $col}')
        fi
        if [ $video_height_idx -ne -1 ]; then
            csv_height=$(echo "$line" | awk -F',' -v col=$((video_height_idx + 1)) '{print $col}')
        fi
        
        # Extract optional output filename if available
        custom_output=""
        if [ $filename_output_idx -ne -1 ]; then
            custom_output=$(echo "$line" | awk -F',' -v col=$((filename_output_idx + 1)) '{print $col}')
        fi
        
        # Skip empty lines
        if [ -z "$filename" ]; then
            continue
        fi
        
        # Validate required fields
        if [ -z "$start_time" ] || [ -z "$end_time" ] || [ -z "$text" ]; then
            if [ "$VERBOSE" = "true" ]; then
                echo "================================"
                echo "Skipping row $line_number: Missing required fields"
                echo "  filename: $filename"
                echo "  START_TIME: '$start_time'"
                echo "  END_TIME: '$end_time'"
                echo "  TEXT: '$text'"
                echo "================================"
                echo ""
            else
                echo "[$line_number] $(basename "$filename") → SKIPPED (missing required fields)"
            fi
            fail_count=$((fail_count + 1))
            continue
        fi
        
        # Construct full input path
        # Only use base path if explicitly provided via CLI
        if [ -n "$CSV_BASE_PATH" ]; then
            input_file="${CSV_BASE_PATH}/${filename}"
        else
            # Use the path as-is from the CSV
            input_file="$filename"
        fi
        
        # Get filename for output (without path)
        base_filename=$(basename "$filename")
        filename_no_ext="${base_filename%.*}"
        extension="${base_filename##*.}"
        
        # Create output filename - use custom if provided, otherwise use default
        if [ -n "$custom_output" ]; then
            # Check if custom output already has an extension
            if [[ "$custom_output" == *.* ]]; then
                # Extension included - use as-is
                output_file="${OUTPUT_DIRECTORY}/${custom_output}"
            else
                # No extension - append the input file's extension
                output_file="${OUTPUT_DIRECTORY}/${custom_output}.${extension}"
            fi
        else
            # Default: add suffix to original filename
            output_file="${OUTPUT_DIRECTORY}/${filename_no_ext}${OUTPUT_SUFFIX}.${extension}"
        fi
        
        # Convert literal \n or \\n from CSV to actual newlines
        # Replace \\n (double backslash) or \n (single backslash) with actual newline
        text_with_newlines=$(echo "$text" | sed 's/\\\\n/\n/g; s/\\n/\n/g')
        
        # In dry run mode, just list the files
        if [ "$DRY_RUN" = "true" ]; then
            echo "[$line_number] $input_file → $output_file"
            success_count=$((success_count + 1))
        else
            # Process the video with optional dimensions from CSV
            if process_video "$input_file" "$output_file" "$text_with_newlines" "$start_time" "$end_time" "$csv_width" "$csv_height" "$line_number"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        fi
    done < "$CSV_FILE"
    
    # Calculate final elapsed time
    END_TIME_EPOCH=$(date +%s)
    END_TIME_DISPLAY=$(date '+%Y-%m-%d %H:%M:%S')
    TOTAL_ELAPSED=$((END_TIME_EPOCH - START_TIME_EPOCH))
    
    hours=$((TOTAL_ELAPSED / 3600))
    minutes=$(((TOTAL_ELAPSED % 3600) / 60))
    seconds=$((TOTAL_ELAPSED % 60))
    
    echo "================================"
    if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run complete!"
        echo "Would process: $success_count file(s)"
    else
        echo "CSV processing complete!"
        echo ""
        echo "Started:  $START_TIME_DISPLAY"
        echo "Finished: $END_TIME_DISPLAY"
        printf "Duration: %02d:%02d:%02d\n" $hours $minutes $seconds
        echo ""
        echo "Processed: $((success_count + fail_count)) file(s)"
        echo "Success: $success_count"
        echo "Failed: $fail_count"
    fi
    echo "================================"

elif [ "$BATCH_MODE" = "true" ]; then
    echo "================================"
    echo "BATCH PROCESSING MODE"
    echo "================================"
    echo "Input directory: $INPUT_DIRECTORY"
    echo "Output directory: $OUTPUT_DIRECTORY"
    echo ""
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIRECTORY"
    
    # Find all mp4 and mov files
    shopt -s nullglob
    video_files=("$INPUT_DIRECTORY"/*.mp4 "$INPUT_DIRECTORY"/*.mov "$INPUT_DIRECTORY"/*.MP4 "$INPUT_DIRECTORY"/*.MOV)
    
    if [ ${#video_files[@]} -eq 0 ]; then
        echo "No video files found in $INPUT_DIRECTORY"
        exit 1
    fi
    
    echo "Found ${#video_files[@]} video file(s) to process"
    echo ""
    
    # Process each video file with default text and timing
    for video_file in "${video_files[@]}"; do
        # Get filename without path
        filename=$(basename "$video_file")
        # Get filename without extension
        filename_no_ext="${filename%.*}"
        # Get extension
        extension="${filename##*.}"
        
        # Create output filename
        output_file="${OUTPUT_DIRECTORY}/${filename_no_ext}${OUTPUT_SUFFIX}.${extension}"
        
        process_video "$video_file" "$output_file" "$TEXT" "$START_TIME" "$END_TIME" "" ""
    done
    
    echo "================================"
    echo "Batch processing complete!"
    echo "Processed ${#video_files[@]} file(s)"
    echo "================================"
    
else
    echo "================================"
    echo "SINGLE FILE MODE"
    echo "================================"
    process_video "$INPUT_VIDEO" "$OUTPUT_VIDEO" "$TEXT" "$START_TIME" "$END_TIME" "" ""
    echo "================================"
    echo "Done!"
    echo "================================"
fi