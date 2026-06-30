#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/tmp/perf"
mkdir -p "$OUT_DIR"

generate_file() {
  local target="$1"
  local size_bytes="$2"
  local block
  local block_size
  local repeat_count
  local remainder
  local blocks_per_chunk
  local chunk
  local chunk_count
  local trailing_blocks
  local i
  block=$'# Performance Fixture\n\nThis paragraph is generated for QMark preview performance testing.\n\n- Item one\n- Item two\n- Item three\n\n```swift\nlet value = "QMark"\nprint(value)\n```\n\n| Column | Value |\n| --- | --- |\n| Alpha | Beta |\n\n'

  block_size="$(printf "%s" "$block" | LC_ALL=C wc -c | tr -d '[:space:]')"
  repeat_count=$((size_bytes / block_size))
  remainder=$((size_bytes % block_size))
  blocks_per_chunk=256
  chunk=""

  for ((i = 0; i < blocks_per_chunk; i++)); do
    chunk+="$block"
  done

  chunk_count=$((repeat_count / blocks_per_chunk))
  trailing_blocks=$((repeat_count % blocks_per_chunk))

  : > "$target"

  for ((i = 0; i < chunk_count; i++)); do
    printf "%s" "$chunk" >> "$target"
  done

  for ((i = 0; i < trailing_blocks; i++)); do
    printf "%s" "$block" >> "$target"
  done

  if [ "$remainder" -gt 0 ]; then
    printf "%s" "${block:0:remainder}" >> "$target"
  fi
}

generate_file "$OUT_DIR/markdown-500kb.md" 512000
generate_file "$OUT_DIR/markdown-1mb.md" 1048576
generate_file "$OUT_DIR/markdown-5mb.md" 5242880
generate_file "$OUT_DIR/markdown-10mb.md" 10485760

ls -lh "$OUT_DIR"
