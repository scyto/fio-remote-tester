#!/bin/bash

# === Help message ===
show_help() {
cat <<EOF
📘 FIO Remote Share I/O Tester

Usage:
  ./io-test.sh /path/to/mount --output [csv markdown html]

Examples:
  ./io-test.sh ./mnt/testshare --output csv markdown
  ./io-test.sh /mnt/cephfs --output html

Options:
  --output csv markdown html   Output one or more formats
  -h, --help                   Show this help message

Note:
  The first argument must be the directory to test. This is required.

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


# Parse flags
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --output)
            shift
            if [[ "$#" -eq 0 || "$1" =~ ^-- ]]; then
                echo "❌ Error: --output requires one or more formats (e.g. csv markdown html)"
                exit 1
            fi
            while [[ "$#" -gt 0 && ! "$1" =~ ^-- ]]; do
                case "$1" in
                    csv) OUTPUT_CSV=true ;;
                    markdown) OUTPUT_MD=true ;;
                    html) OUTPUT_HTML=true ;;
                    *)
                        echo "❌ Unknown output format: $1"
                        echo "✅ Supported formats: csv, markdown, html"
                        exit 1
                        ;;
                esac
                shift
            done
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "✅ Usage: ./io-test.sh [path] --output [csv markdown html]"
            exit 1
            ;;
    esac
done

# Timestamp for filenames
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
TEST_ABS_PATH=$(realpath "$TEST_DIR")

# Paths
TEST_FILE="$TEST_DIR/testfile.tmp"
SIZE="512M"
LOG_FILE="fio-results-$TIMESTAMP.log"
SUMMARY_TXT="fio-summary-$TIMESTAMP.txt"
SUMMARY_CSV="fio-summary-$TIMESTAMP.csv"
SUMMARY_MD="fio-summary-$TIMESTAMP.md"
SUMMARY_HTML="fio-summary-$TIMESTAMP.html"

echo "📁 Running tests in: $TEST_ABS_PATH" | tee "$LOG_FILE"
echo "🧪 Temporary test file: $TEST_FILE" | tee -a "$LOG_FILE"
echo "📄 Logging to: $LOG_FILE"
echo | tee -a "$LOG_FILE"

# Check for fio
if ! command -v fio >/dev/null 2>&1; then
    echo "❌ 'fio' not found. Install it with: sudo apt install fio"
    exit 1
fi

cd "$TEST_DIR" || { echo "❌ Could not access $TEST_DIR"; exit 1; }

run_test() {
    local NAME="$1"
    shift
    echo "🚀 Running: $NAME" | tee -a "$LOG_FILE"
    fio --name="$NAME" --filename="$TEST_FILE" --size="$SIZE" "$@" --output-format=normal >> "$LOG_FILE" 2>&1
    echo | tee -a "$LOG_FILE"
}

# Run tests
run_test seqwrite --bs=1M --rw=write --iodepth=1 --direct=1
run_test seqread  --bs=1M --rw=read  --iodepth=1 --direct=1
run_test randrw   --bs=4k --rw=randrw --rwmixread=70 --iodepth=4 --direct=1

# Init summaries
{
  echo "📊 FIO Summary"
  echo "🕒 Timestamp: $TIMESTAMP"
  echo "📂 Tested path: $TEST_ABS_PATH"
  echo ""
  printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" "Test" "Read MB/s" "Write MB/s" "Read IOPS" "Write IOPS"
  echo "|-------------|------------|------------|-----------|------------|"
} > "$SUMMARY_TXT"

$OUTPUT_CSV && echo "Test,Read MB/s,Write MB/s,Read IOPS,Write IOPS,Path,Timestamp" > "$SUMMARY_CSV"
$OUTPUT_MD && {
  echo "## FIO Test Summary" > "$SUMMARY_MD"
  echo "- Timestamp: \`$TIMESTAMP\`" >> "$SUMMARY_MD"
  echo "- Tested Path: \`$TEST_ABS_PATH\`" >> "$SUMMARY_MD"
  echo "" >> "$SUMMARY_MD"
  echo "| Test        | Read MB/s  | Write MB/s | Read IOPS | Write IOPS |" >> "$SUMMARY_MD"
  echo "|-------------|------------|------------|-----------|------------|" >> "$SUMMARY_MD"
}
$OUTPUT_HTML && {
  echo "<p><strong>FIO Test Summary</strong><br>" > "$SUMMARY_HTML"
  echo "Tested path: <code>$TEST_ABS_PATH</code><br>" >> "$SUMMARY_HTML"
  echo "Timestamp: <code>$TIMESTAMP</code></p>" >> "$SUMMARY_HTML"
  echo "<table><thead><tr><th>Test</th><th>Read MB/s</th><th>Write MB/s</th><th>Read IOPS</th><th>Write IOPS</th></tr></thead><tbody>" >> "$SUMMARY_HTML"
}

parse_human_metrics() {
    local TEST="$1"
    local BS_BYTES READ_LINE WRITE_LINE
    local READ_BW WRITE_BW READ_IOPS WRITE_IOPS

    if [[ "$TEST" == "randrw" ]]; then BS_BYTES=4096; else BS_BYTES=1048576; fi

    TEST_START_LINE=$(grep -n "🚀 Running: $TEST" "$LOG_FILE" | cut -d: -f1)
    NEXT_TEST_LINE=$(grep -n "🚀 Running:" "$LOG_FILE" | awk -v start="$TEST_START_LINE" '$1 > start { print $1; exit }' FS=":")
    [[ -z "$NEXT_TEST_LINE" ]] && NEXT_TEST_LINE=$(wc -l < "$LOG_FILE")

    LOG_CHUNK=$(sed -n "${TEST_START_LINE},${NEXT_TEST_LINE}p" "$LOG_FILE")
    READ_LINE=$(echo "$LOG_CHUNK" | grep 'READ:' | tail -n1)
    WRITE_LINE=$(echo "$LOG_CHUNK" | grep 'WRITE:' | tail -n1)

    READ_BW=$(echo "$READ_LINE" | sed -n 's/.*bw=\([^ ]*\).*/\1/p')
    WRITE_BW=$(echo "$WRITE_LINE" | sed -n 's/.*bw=\([^ ]*\).*/\1/p')

    READ_IOPS=$(echo "$READ_BW" | awk -v bs="$BS_BYTES" '
        /MiB\/s/ { sub("MiB/s", "", $1); printf "%d", $1 * 1048576 / bs; next }
        /KiB\/s/ { sub("KiB/s", "", $1); printf "%d", $1 * 1024 / bs; next }
        /B\/s/   { sub("B/s", "", $1);   printf "%d", $1 / bs; next }
        /^$/     { print "-" }
    ')
    WRITE_IOPS=$(echo "$WRITE_BW" | awk -v bs="$BS_BYTES" '
        /MiB\/s/ { sub("MiB/s", "", $1); printf "%d", $1 * 1048576 / bs; next }
        /KiB\/s/ { sub("KiB/s", "", $1); printf "%d", $1 * 1024 / bs; next }
        /B\/s/   { sub("B/s", "", $1);   printf "%d", $1 / bs; next }
        /^$/     { print "-" }
    ')

    printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" \
        "$TEST" "${READ_BW:-0}" "${WRITE_BW:-0}" "${READ_IOPS:-"-"}" "${WRITE_IOPS:-"-"}" >> "$SUMMARY_TXT"

    $OUTPUT_CSV && echo "$TEST,${READ_BW:-0},${WRITE_BW:-0},${READ_IOPS:-"-"},${WRITE_IOPS:-"-"},$TEST_ABS_PATH,$TIMESTAMP" >> "$SUMMARY_CSV"
    $OUTPUT_MD && printf "| %-11s | %-10s | %-10s | %-9s | %-10s |\n" \
        "$TEST" "${READ_BW:-0}" "${WRITE_BW:-0}" "${READ_IOPS:-"-"}" "${WRITE_IOPS:-"-"}" >> "$SUMMARY_MD"
    $OUTPUT_HTML && echo "<tr><td>$TEST</td><td>${READ_BW:-0}</td><td>${WRITE_BW:-0}</td><td>${READ_IOPS:-"-"}</td><td>${WRITE_IOPS:-"-"}</td></tr>" >> "$SUMMARY_HTML"
}

parse_human_metrics seqwrite
parse_human_metrics seqread
parse_human_metrics randrw

$OUTPUT_HTML && echo "</tbody></table>" >> "$SUMMARY_HTML"

echo -e "\n🧹 Cleaning up..." | tee -a "$LOG_FILE"
rm -f "$TEST_FILE"
echo "✅ Done." | tee -a "$LOG_FILE"

echo
cat "$SUMMARY_TXT"

# Inform user of outputs
echo
echo "📤 Output files generated:"
echo "- Summary:      $SUMMARY_TXT"
$OUTPUT_CSV && echo "- CSV:          $SUMMARY_CSV"
$OUTPUT_MD && echo "- Markdown:     $SUMMARY_MD"
$OUTPUT_HTML && echo "- HTML:         $SUMMARY_HTML"
echo "- Raw fio log:  $LOG_FILE"
echo
