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
# ... [TRUNCATED for brevity; would include the full fixed script here]
