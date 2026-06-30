#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/tmp/perf"
mkdir -p "$OUT_DIR"

generate_file() {
  local target="$1"
  local size_bytes="$2"
  local block
  block=$'# Performance Fixture\n\nThis paragraph is generated for QMark preview performance testing.\n\n- Item one\n- Item two\n- Item three\n\n```swift\nlet value = "QMark"\nprint(value)\n```\n\n| Column | Value |\n| --- | --- |\n| Alpha | Beta |\n\n'

  : > "$target"
  while [ "$(wc -c < "$target")" -lt "$size_bytes" ]; do
    printf "%s" "$block" >> "$target"
  done
}

generate_file "$OUT_DIR/markdown-500kb.md" 512000
generate_file "$OUT_DIR/markdown-1mb.md" 1048576
generate_file "$OUT_DIR/markdown-5mb.md" 5242880
generate_file "$OUT_DIR/markdown-10mb.md" 10485760

ls -lh "$OUT_DIR"
