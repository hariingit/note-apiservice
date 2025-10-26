#!/usr/bin/env bash
set -euo pipefail

# log_summarizer.sh
#
# Usage:
#   ./log_summarizer.sh <input_dir> <output_file>
#
# Example:
#   ./log_summarizer.sh sample-logs out.jsonl
#
# Description:
# - Processes all .log and .log.gz files in <input_dir>, handling filenames with spaces.
# - Extracts lines containing "error" (case-insensitive).
# - Groups by minute (first 16 chars timestamp + "Z") and error signature.
# - Counts occurrences per minute and signature.
# - Outputs JSON lines to <output_file> with fields: minute, signature, count.
# - Exits with code 1 and prints error if any minute-signature count exceeds 100.
#
# Prerequisites:
# - 'gunzip' command must be available to decompress .gz files.
# - Read access to all log files in <input_dir>.

INPUT_DIR="$1"
OUTPUT_FILE="$2"

# Create or truncate output file
> "$OUTPUT_FILE"

exit_code=0

find "$INPUT_DIR" -type f \( -name '*.log' -o -name '*.log.gz' \) -print0 | \
while IFS= read -r -d '' file; do
  if [[ "$file" == *.gz ]]; then
    gunzip -c "$file"
  else
    cat "$file"
  fi
done | grep -i error | while IFS= read -r line; do
  # Extract first 16 chars as minute (e.g. 2025-10-27T01:26) and append "Z"
  minute=$(echo "$line" | cut -c1-16)Z
  echo "$minute|$line"
done | sort | uniq -c | while read -r count rest; do
  minute=$(echo "$rest" | cut -d'|' -f1)
  signature=$(echo "$rest" | cut -d'|' -f2-)
  echo "{\"minute\":\"$minute\",\"signature\":\"$signature\",\"count\":$count}"
  if (( count > 100 )); then
    exit_code=1
  fi
done > "$OUTPUT_FILE"

if (( exit_code != 0 )); then
  echo "ERROR: One or more minute-signature counts exceed 100" >&2
fi

exit $exit_code

