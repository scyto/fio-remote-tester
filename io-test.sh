#!/bin/bash

# === Help message ===
show_help() {
cat <<EOF
📘 FIO I/O Tester

Usage:
  ./io-test.sh /path/to/mount --profile [default|balanced|vm|webserver|stress] --output [csv markdown html all] [--clear-cache]

Examples:
  ./io-test.sh ./mnt/share --profile vm --output markdown --clear-cache

Options:
  --profile default|balanced|vm|webserver|stress  Select a predefined I/O workload profile
  --output csv markdown html none                 Output one or more formats or 'all' for all formats, 'none' to disable file output
  --clear-cache                                   Runs FIO tests with '--direct=1', '--invlidate=1' and clears Linux disk caches before each test (requires root)
  -h, --help                                      Show this help message
EOF
}

# === Handle help or missing path ===
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        show_help
        exit 0
    fi
done

if [[ -z "$1" || "$1" =~ ^-- ]]; then
    echo "❌ Error: Missing test path."
    echo "✅ Run with --help for usage instructions."
    exit 1
fi

TEST_DIR="$1"
shift

OUTPUT_CSV=false
OUTPUT_MD=false
OUTPUT_HTML=false
OUTPUT_NONE=false
CLEAR_CACHE=false
PROFILE="default"

VALID_PROFILES=(default balanced vm webserver stress)
VALID_OUTPUTS=(csv markdown html)

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --output)
            shift
            while [[ "$#" -gt 0 && ! "$1" =~ ^-- ]]; do
                if [[ "$1" == "all" ]]; then
                    OUTPUT_CSV=true
                    OUTPUT_MD=true
                    OUTPUT_HTML=true
                elif [[ "$1" == "none" ]]; then
                    OUTPUT_CSV=false
                    OUTPUT_MD=false
                    OUTPUT_HTML=false
                    OUTPUT_NONE=true
                elif [[ " ${VALID_OUTPUTS[*]} " =~ " $1 " ]]; then
                    [[ "$1" == "csv" ]] && OUTPUT_CSV=true
                    [[ "$1" == "markdown" ]] && OUTPUT_MD=true
                    [[ "$1" == "html" ]] && OUTPUT_HTML=true
                else
                    echo "❌ Unknown output format: $1"
                    echo "✅ Valid output formats: ${VALID_OUTPUTS[*]} or 'all' or 'none'"
                    exit 1
                fi
                shift
            done
            ;;
        --profile)
            shift
            if [[ " ${VALID_PROFILES[*]} " =~ " $1 " ]]; then
                PROFILE="$1"
            else
                echo "❌ Unknown profile: $1"
                echo "✅ Valid profiles: ${VALID_PROFILES[*]}"
                exit 1
            fi
            shift
            ;;
        --clear-cache)
            CLEAR_CACHE=true
            shift
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "✅ Run with --help for usage instructions."
            exit 1
            ;;
    esac
done

# === check for sudo if --clear-cache is set ===
if $CLEAR_CACHE && [[ "$EUID" -ne 0 ]]; then
    echo "❌ Error: The --clear-cache option requires root privileges."
    echo "✅ Please run the script with sudo: sudo ./io-test.sh ..."
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_ABS_PATH=$(realpath "$TEST_DIR")
LOG_FILE="$PWD/fio-results-$TIMESTAMP.log"
SUMMARY_TXT="$PWD/fio-summary-$TIMESTAMP.txt"
SUMMARY_CSV="$PWD/fio-summary-$TIMESTAMP.csv"
SUMMARY_MD="$PWD/fio-summary-$TIMESTAMP.md"
SUMMARY_HTML="$PWD/fio-summary-$TIMESTAMP.html"

echo "📁 Running tests in: $TEST_ABS_PATH" | tee "$LOG_FILE"
echo "🧪 Temporary test files in: $TEST_ABS_PATH" | tee -a "$LOG_FILE"
echo "📄 Logging to: $LOG_FILE"
echo "📄 Profile selected: $PROFILE"
$CLEAR_CACHE && echo "🧹 Disk cache clearing enabled before each test" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

if ! command -v fio >/dev/null; then
    echo "❌ 'fio' is not installed. Please run: sudo apt install fio"
    exit 1
fi

cd "$TEST_DIR" || { echo "❌ Could not access $TEST_DIR"; exit 1; }

TEST_NAMES=()

clear_caches() {
    echo "🧹 Clearing disk caches..." | tee -a "$LOG_FILE"
    sync
    echo 3 > /proc/sys/vm/drop_caches
}

run_test() {
    local NAME="$1"
    local FILE="$TEST_DIR/testfile-$NAME.tmp"
    shift
    TEST_NAMES+=("$NAME")

    $CLEAR_CACHE && clear_caches

    echo "🚀 Running: $NAME" | tee -a "$LOG_FILE"

    local FIO_ARGS=(
        --name="$NAME"
        --filename="$FILE"
        --size=512M
        --overwrite=1
        --output-format=normal
    )

    if $CLEAR_CACHE; then
        FIO_ARGS+=(--direct=1 --invalidate=1)
    fi

    # Explicitly expand user args *after* FIO_ARGS so they take effect
    fio "${FIO_ARGS[@]}" "$@" >> "$LOG_FILE" 2>&1
    echo | tee -a "$LOG_FILE"
}

run_profile() {
    case "$PROFILE" in
        default)
            run_test seqwrite-1M --rw=write    --bs=1M  --iodepth=1  --ioengine=libaio --time_based --runtime=30 
            run_test seqread-1M  --rw=read     --bs=1M  --iodepth=1  --ioengine=libaio --time_based --runtime=30 
            run_test randrw-4k   --rw=randrw   --bs=4k  --rwmixread=70 --iodepth=4  --ioengine=libaio --time_based --runtime=30 
            ;;
        balanced)
            run_test seqwrite-1M --rw=write    --bs=1M  --iodepth=2  --ioengine=libaio --time_based --runtime=30 
            run_test randread-4k --rw=randread --bs=4k  --iodepth=16 --ioengine=libaio --time_based --runtime=30 --direct=1
            run_test randrw-16k  --rw=randrw   --bs=16k --rwmixread=70 --iodepth=8 --ioengine=libaio --time_based --runtime=30
            run_test seqread-4M  --rw=read     --bs=4M  --iodepth=2  --ioengine=libaio --time_based --runtime=30 
            ;;
        vm)
            run_test randread-8k   --rw=randread  --bs=8k  --iodepth=32 --ioengine=libaio --time_based --runtime=30 
            run_test randwrite-8k  --rw=randwrite --bs=8k  --iodepth=32 --ioengine=libaio --time_based --runtime=30 
            run_test randrw-16k    --rw=randrw    --bs=16k --rwmixread=70 --iodepth=16 --ioengine=libaio --time_based --runtime=30 
            run_test seqread-1M    --rw=read      --bs=1M  --iodepth=2  --ioengine=libaio --time_based --runtime=30 
            ;;
        webserver)
            run_test randread-4k   --rw=randread  --bs=4k  --iodepth=64 --ioengine=libaio --time_based --runtime=30 
            run_test randwrite-4k  --rw=randwrite --bs=4k  --iodepth=64 --ioengine=libaio --time_based --runtime=30 
            run_test randrw-16k    --rw=randrw    --bs=16k --rwmixread=90 --iodepth=32 --ioengine=libaio --time_based --runtime=30
            run_test seqread-512k  --rw=read      --bs=512k --iodepth=4 --ioengine=libaio --time_based --runtime=30 
            ;;
        stress)
            run_test randrw-4k     --rw=randrw    --bs=4k   --rwmixread=50 --iodepth=64 --ioengine=libaio --time_based --runtime=30 
            run_test randrw-64k    --rw=randrw    --bs=64k  --rwmixread=50 --iodepth=64 --ioengine=libaio --time_based --runtime=30 
            run_test randwrite-1M  --rw=randwrite --bs=1M   --iodepth=32 --ioengine=libaio --time_based --runtime=30 
            run_test randread-1M   --rw=randread  --bs=1M   --iodepth=32 --ioengine=libaio --time_based --runtime=30 
            ;;
    esac
}

# Header output
{
  echo "📊 FIO Summary"
  echo "🕒 Timestamp: $TIMESTAMP"
  echo "📂 Tested path: $TEST_ABS_PATH"
  echo "📄 Profile: $PROFILE"
  echo ""
  printf "| %-14s | %-10s | %-10s | %-9s | %-10s |\n" "Test" "Read MB/s" "Write MB/s" "Read IOPS" "Write IOPS"
  echo "|----------------|------------|------------|-----------|------------|"
} > "$SUMMARY_TXT"

$OUTPUT_CSV && echo "Test,Read MB/s,Write MB/s,Read IOPS,Write IOPS,Path,Timestamp,Profile" > "$SUMMARY_CSV"
$OUTPUT_MD && {
  echo "## FIO Test Summary" > "$SUMMARY_MD"
  echo "- Timestamp: \`$TIMESTAMP\`" >> "$SUMMARY_MD"
  echo "- Tested Path: \`$TEST_ABS_PATH\`" >> "$SUMMARY_MD"
  echo "- Profile: \`$PROFILE\`" >> "$SUMMARY_MD"
  echo "" >> "$SUMMARY_MD"
  echo "| Test           | Read MB/s  | Write MB/s | Read IOPS | Write IOPS |" >> "$SUMMARY_MD"
  echo "|----------------|------------|------------|-----------|------------|" >> "$SUMMARY_MD"
}
$OUTPUT_HTML && {
  echo "<p><strong>FIO Test Summary</strong><br>" > "$SUMMARY_HTML"
  echo "Tested path: <code>$TEST_ABS_PATH</code><br>" >> "$SUMMARY_HTML"
  echo "Timestamp: <code>$TIMESTAMP</code><br>" >> "$SUMMARY_HTML"
  echo "Profile: <code>$PROFILE</code></p>" >> "$SUMMARY_HTML"
  echo "<table><thead><tr><th>Test</th><th>Read MB/s</th><th>Write MB/s</th><th>Read IOPS</th><th>Write IOPS</th></tr></thead><tbody>" >> "$SUMMARY_HTML"
}

parse_human_metrics() {
    local TEST="$1"
    local CHUNK RW_MODE READ_BW WRITE_BW READ_IOPS WRITE_IOPS
    CHUNK=$(awk "/🚀 Running: $TEST/,/🚀 Running: /" "$LOG_FILE" | head -n -1)
    [[ -z "$CHUNK" ]] && CHUNK=$(awk "/🚀 Running: $TEST/,/Cleaning up.../" "$LOG_FILE")

    RW_MODE=$(echo "$CHUNK" | grep -Eo 'rw=(read|write|randread|randwrite|randrw)' | head -n1 | cut -d= -f2)
    READ_BW=$(echo "$CHUNK" | grep -i 'read:' | sed -n 's/.*bw=\([^, ]*\).*/\1/p' | head -n1)
    WRITE_BW=$(echo "$CHUNK" | grep -i 'write:' | sed -n 's/.*bw=\([^, ]*\).*/\1/p' | head -n1)
    READ_IOPS=$(echo "$CHUNK" | grep -i 'read:' | sed -n 's/.*IOPS=\([^, ]*\).*/\1/p' | head -n1)
    WRITE_IOPS=$(echo "$CHUNK" | grep -i 'write:' | sed -n 's/.*IOPS=\([^, ]*\).*/\1/p' | head -n1)

    [[ "$RW_MODE" =~ ^write|randwrite$ ]] && READ_BW="0" READ_IOPS="-"
    [[ "$RW_MODE" =~ ^read|randread$ ]]   && WRITE_BW="0" WRITE_IOPS="-"

    printf "| %-14s | %-10s | %-10s | %-9s | %-10s |\n" \
        "$TEST" "${READ_BW:-0}" "${WRITE_BW:-0}" "${READ_IOPS:--}" "${WRITE_IOPS:--}" >> "$SUMMARY_TXT"
    $OUTPUT_CSV && echo "$TEST,$READ_BW,$WRITE_BW,$READ_IOPS,$WRITE_IOPS,$TEST_ABS_PATH,$TIMESTAMP,$PROFILE" >> "$SUMMARY_CSV"
    $OUTPUT_MD && printf "| %-14s | %-10s | %-10s | %-9s | %-10s |\n" "$TEST" "$READ_BW" "$WRITE_BW" "$READ_IOPS" "$WRITE_IOPS" >> "$SUMMARY_MD"
    $OUTPUT_HTML && echo "<tr><td>$TEST</td><td>$READ_BW</td><td>$WRITE_BW</td><td>$READ_IOPS</td><td>$WRITE_IOPS</td></tr>" >> "$SUMMARY_HTML"
}

run_profile
for TEST in "${TEST_NAMES[@]}"; do
    parse_human_metrics "$TEST"
done
$OUTPUT_HTML && echo "</tbody></table>" >> "$SUMMARY_HTML"

echo -e "\n🧹 Cleaning up..." | tee -a "$LOG_FILE"
rm -f "$TEST_DIR"/testfile-*.tmp
echo "✅ Done." | tee -a "$LOG_FILE"
echo
cat "$SUMMARY_TXT"
echo
echo "📤 Output files generated (profile: $PROFILE):"
echo "- Summary:      $SUMMARY_TXT"
$OUTPUT_CSV && echo "- CSV:          $SUMMARY_CSV"
$OUTPUT_MD && echo "- Markdown:     $SUMMARY_MD"
$OUTPUT_HTML && echo "- HTML:         $SUMMARY_HTML"
echo "- Raw fio log:  $LOG_FILE"

#=== Delete log and summary files if --output none was specified ===
if [[ "$OUTPUT_NONE" == true ]]; then
    echo "🗑️ Deleting log and summary files as '--output none' was specified."
    rm -f "$LOG_FILE" "$SUMMARY_TXT"
fi