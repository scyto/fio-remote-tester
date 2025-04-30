#!/bin/bash

# === Help message ===
show_help() {
cat <<EOF
📘 FIO Remote Share I/O Tester

Usage:
  ./io-test.sh /path/to/mount --profile [default|balanced|vm|webserver|stress] --output [csv markdown html]

Examples:
  ./io-test.sh ./mnt/testshare --profile balanced --output csv markdown
  ./io-test.sh /mnt/cephfs --output html

Options:
  --profile default|balanced|vm|webserver|stress  Select a predefined I/O workload profile
  --output csv markdown html                      Output one or more formats
  -h, --help                                      Show this help message

EOF
}

# === Handle --help or missing path ===
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ -z "$1" || "$1" =~ ^-- ]]; then
    echo "❌ Error: Missing test path."
    echo "✅ Run with --help for usage instructions."
    exit 1
fi

TEST_DIR="$1"
shift

# Output format flags
OUTPUT_CSV=false
OUTPUT_MD=false
OUTPUT_HTML=false
PROFILE="default"

# === Parse arguments ===
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --output)
            shift
            while [[ "$#" -gt 0 && ! "$1" =~ ^-- ]]; do
                case "$1" in
                    csv) OUTPUT_CSV=true ;;
                    markdown) OUTPUT_MD=true ;;
                    html) OUTPUT_HTML=true ;;
                    *) echo "❌ Unknown output format: $1"; exit 1 ;;
                esac
                shift
            done
            ;;
        --profile)
            shift
            case "$1" in
                default|balanced|vm|webserver|stress) PROFILE="$1" ;;
                *) echo "❌ Unknown profile: $1"; echo "✅ Supported: default, balanced, vm, webserver, stress"; exit 1 ;;
            esac
            shift
            ;;
        *) echo "❌ Unknown argument: $1"; echo "✅ Run with --help for usage."; exit 1 ;;
    esac
done

# Timestamp and path
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_ABS_PATH=$(realpath "$TEST_DIR")

# Output filenames
TEST_FILE="$TEST_DIR/testfile.tmp"
LOG_FILE="fio-results-$TIMESTAMP.log"
SUMMARY_TXT="fio-summary-$TIMESTAMP.txt"
SUMMARY_CSV="fio-summary-$TIMESTAMP.csv"
SUMMARY_MD="fio-summary-$TIMESTAMP.md"
SUMMARY_HTML="fio-summary-$TIMESTAMP.html"

echo "📁 Running tests in: $TEST_ABS_PATH" | tee "$LOG_FILE"
echo "🧪 Temporary test file: $TEST_FILE" | tee -a "$LOG_FILE"
echo "📄 Logging to: $LOG_FILE"
echo "📄 Profile selected: $PROFILE"
echo | tee -a "$LOG_FILE"

if ! command -v fio >/dev/null; then
    echo "❌ 'fio' is not installed. Please run: sudo apt install fio"
    exit 1
fi

cd "$TEST_DIR" || { echo "❌ Could not access $TEST_DIR"; exit 1; }

TEST_NAMES=()

run_test() {
    local NAME="$1"
    TEST_NAMES+=("$NAME")
    shift
    echo "🚀 Running: $NAME" | tee -a "$LOG_FILE"
    fio --name="$NAME" --filename="$TEST_FILE" --size="512M" "$@" --output-format=normal >> "$LOG_FILE" 2>&1
    echo | tee -a "$LOG_FILE"
}

run_profile() {
    case "$PROFILE" in
        default)
            run_test seqwrite --bs=1M --rw=write --iodepth=1 --direct=1
            run_test seqread  --bs=1M --rw=read  --iodepth=1 --direct=1
            run_test randrw   --bs=4k --rw=randrw --rwmixread=70 --iodepth=4 --direct=1
            ;;
        balanced)
            run_test seqwrite --bs=1M --rw=write --iodepth=2 --direct=1
            run_test randread --bs=4k --rw=randread --iodepth=16 --direct=1
            run_test randrw   --bs=16k --rw=randrw --rwmixread=70 --iodepth=8 --direct=1
            run_test seqread  --bs=4M --rw=read --iodepth=2 --direct=1
            ;;
        vm)
            run_test randread  --bs=8k  --rw=randread  --iodepth=32 --direct=1
            run_test randwrite --bs=8k  --rw=randwrite --iodepth=32 --direct=1
            run_test randrw    --bs=16k --rw=randrw    --rwmixread=70 --iodepth=16 --direct=1
            run_test seqread   --bs=1M  --rw=read      --iodepth=2   --direct=1
            ;;
        webserver)
            run_test randread  --bs=4k  --rw=randread  --iodepth=64 --direct=1
            run_test randwrite --bs=4k  --rw=randwrite --iodepth=64 --direct=1
            run_test randrw    --bs=16k --rw=randrw    --rwmixread=90 --iodepth=32 --direct=1
            run_test seqread   --bs=512k --rw=read     --iodepth=4  --direct=1
            ;;
        stress)
            run_test randrw    --bs=4k   --rw=randrw    --rwmixread=50 --iodepth=64 --direct=1
            run_test randrw    --bs=64k  --rw=randrw    --rwmixread=50 --iodepth=64 --direct=1
            run_test randwrite --bs=1M   --rw=randwrite --iodepth=32 --direct=1
            run_test randread  --bs=1M   --rw=randread  --iodepth=32 --direct=1
            ;;
    esac
}

# === Output headers ===
{
  echo "📊 FIO Summary"
  echo "🕒 Timestamp: $TIMESTAMP"
  echo "📂 Tested path: $TEST_ABS_PATH"
  echo "📄 Profile: $PROFILE"
  echo ""
  printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" "Test" "Read MB/s" "Write MB/s" "Read IOPS" "Write IOPS"
  echo "|-------------|------------|------------|-----------|------------|"
} > "$SUMMARY_TXT"

$OUTPUT_CSV && echo "Test,Read MB/s,Write MB/s,Read IOPS,Write IOPS,Path,Timestamp,Profile" > "$SUMMARY_CSV"
$OUTPUT_MD && {
  echo "## FIO Test Summary" > "$SUMMARY_MD"
  echo "- Timestamp: \`$TIMESTAMP\`" >> "$SUMMARY_MD"
  echo "- Tested Path: \`$TEST_ABS_PATH\`" >> "$SUMMARY_MD"
  echo "- Profile: \`$PROFILE\`" >> "$SUMMARY_MD"
  echo "" >> "$SUMMARY_MD"
  echo "| Test        | Read MB/s  | Write MB/s | Read IOPS | Write IOPS |" >> "$SUMMARY_MD"
  echo "|-------------|------------|------------|-----------|------------|" >> "$SUMMARY_MD"
}
$OUTPUT_HTML && {
  echo "<p><strong>FIO Test Summary</strong><br>" > "$SUMMARY_HTML"
  echo "Tested path: <code>$TEST_ABS_PATH</code><br>" >> "$SUMMARY_HTML"
  echo "Timestamp: <code>$TIMESTAMP</code><br>" >> "$SUMMARY_HTML"
  echo "Profile: <code>$PROFILE</code></p>" >> "$SUMMARY_HTML"
  echo "<table><thead><tr><th>Test</th><th>Read MB/s</th><th>Write MB/s</th><th>Read IOPS</th><th>Write IOPS</th></tr></thead><tbody>" >> "$SUMMARY_HTML"
}

# === Metrics parser (corrected) ===
parse_human_metrics() {
    local TEST="$1"
    local CHUNK
    local READ_BW="0" WRITE_BW="0" READ_IOPS="-" WRITE_IOPS="-"
    local BS_BYTES=4096

    # Extract the chunk from '🚀 Running: $TEST' until the next '🚀 Running:' or EOF
    CHUNK=$(awk "/🚀 Running: $TEST/,/🚀 Running: /" "$LOG_FILE" | head -n -1)

    # Special case for last block (no trailing marker)
    if [[ -z "$CHUNK" ]]; then
        CHUNK=$(awk "/🚀 Running: $TEST/,/Cleaning up.../" "$LOG_FILE")
    fi

    # Extract bandwidth and IOPS from lowercase 'read:' and 'write:'
    READ_BW=$(echo "$CHUNK" | grep -i 'read:' | sed -n 's/.*bw=\([^, ]*\).*/\1/p' | head -n 1)
    WRITE_BW=$(echo "$CHUNK" | grep -i 'write:' | sed -n 's/.*bw=\([^, ]*\).*/\1/p' | head -n 1)
    READ_IOPS=$(echo "$CHUNK" | grep -i 'read:' | sed -n 's/.*IOPS=\([^, ]*\).*/\1/p' | head -n 1)
    WRITE_IOPS=$(echo "$CHUNK" | grep -i 'write:' | sed -n 's/.*IOPS=\([^, ]*\).*/\1/p' | head -n 1)

    # Fallbacks
    READ_BW=${READ_BW:-0}
    WRITE_BW=${WRITE_BW:-0}
    READ_IOPS=${READ_IOPS:-"-"}
    WRITE_IOPS=${WRITE_IOPS:-"-"}

    # Output to text
    printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" \
        "$TEST" "$READ_BW" "$WRITE_BW" "$READ_IOPS" "$WRITE_IOPS" >> "$SUMMARY_TXT"

    $OUTPUT_CSV && echo "$TEST,$READ_BW,$WRITE_BW,$READ_IOPS,$WRITE_IOPS,$TEST_ABS_PATH,$TIMESTAMP,$PROFILE" >> "$SUMMARY_CSV"
    $OUTPUT_MD && printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" \
        "$TEST" "$READ_BW" "$WRITE_BW" "$READ_IOPS" "$WRITE_IOPS" >> "$SUMMARY_MD"
    $OUTPUT_HTML && echo "<tr><td>$TEST</td><td>$READ_BW</td><td>$WRITE_BW</td><td>$READ_IOPS</td><td>$WRITE_IOPS</td></tr>" >> "$SUMMARY_HTML"
}


# === Execute and summarize ===
run_profile
for TEST in "${TEST_NAMES[@]}"; do
    parse_human_metrics "$TEST"
done
$OUTPUT_HTML && echo "</tbody></table>" >> "$SUMMARY_HTML"

# === Cleanup ===
echo -e "\n🧹 Cleaning up..." | tee -a "$LOG_FILE"
rm -f "$TEST_FILE"
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
echo
