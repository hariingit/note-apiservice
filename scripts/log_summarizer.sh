#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="$1"
OUTPUT_FILE="$2"
MINUTES_WINDOW="${3:-15}"

# Create/empty output file
> "$OUTPUT_FILE"

# Process plain and gzipped logs safely
find "$INPUT_DIR" -type f \( -name '*.log' -o -name '*.log.gz' \) -print0 | while IFS= read -r -d '' file; do
  if [[ "$file" == *.gz ]]; then
    gzip -dc "$file"
  else
    cat "$file"
  fi
done | grep -i error | while read -r line; do
  minute=$(echo "$line" | cut -c1-16)Z
  signature="$line"
  echo "$minute|$signature"
done | sort | uniq -c | while read -r count rest; do
  minute=${rest%%|*}
  signature=${rest#*|}
  echo "{\"minute\":\"$minute\",\"signature\":\"$signature\",\"count\":$count}" >> "$OUTPUT_FILE"
done

echo "OK"
