#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./log_summarizer.sh <input_dir> <output_file>
#
# Example:
#   ./log_summarizer.sh sample-logs out.jsonl
#
# Prerequisites:
# - The input directory (<input_dir>) must exist and contain .log or .log.gz files.
# - 'gunzip' command must be installed to decompress .gz files.
#   On most Linux systems, 'gunzip' is part of the gzip package.
# - The script requires read access to all log files.
# - If no .log or .log.gz files exist in the input directory, the output will be empty.

INPUT_DIR="$1"
OUTPUT_FILE="$2"

# Empty output file (create or clear)
> "$OUTPUT_FILE"

# Process all log files by decompressing .gz files and concatenating plain logs
find "$INPUT_DIR" -type f \( -name '*.log' -o -name '*.log.gz' \) -print0 | \
while IFS= read -r -d '' file; do
  if [[ "$file" == *.gz ]]; then
    gunzip -c "$file"
  else
    cat "$file"
  fi
done | grep -i error | while IFS= read -r line; do
  minute=$(echo "$line" | cut -c1-16)Z
  echo "$minute|$line"
done | sort | uniq -c | while read -r count rest; do
  minute=$(echo "$rest" | cut -d'|' -f1)
  signature=$(echo "$rest" | cut -d'|' -f2-)
  echo "{\"minute\":\"$minute\",\"signature\":\"$signature\",\"count\":$count}"
done > "$OUTPUT_FILE"

echo "OK"

