#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/EditorRenderer/libs"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo "==> Setting up temporary build environment..."
cd "$TEMP_DIR"

cat > package.json << 'PKGJSON'
{
  "name": "qmark-editor-bundle",
  "private": true,
  "type": "module"
}
PKGJSON

npm install codemirror @codemirror/lang-markdown @codemirror/language-data esbuild

echo "==> Creating entry point..."
cat > entry.js << 'ENTRY'
// Expose CodeMirror modules as a global object for non-module usage in WKWebView
import {EditorView, basicSetup} from "codemirror"
import {EditorState} from "@codemirror/state"
import {keymap} from "@codemirror/view"
import {markdown, markdownLanguage} from "@codemirror/lang-markdown"
import {languages} from "@codemirror/language-data"
import {HighlightStyle, syntaxHighlighting} from "@codemirror/language"
import {tags} from "@lezer/highlight"

window.CM = {EditorView, EditorState, basicSetup, keymap, markdown, markdownLanguage, languages, HighlightStyle, syntaxHighlighting, tags}
ENTRY

echo "==> Bundling with esbuild..."
npx esbuild entry.js \
  --bundle \
  --minify \
  --format=iife \
  --outfile=codemirror.min.js

echo "==> Copying to $OUT_DIR..."
mkdir -p "$OUT_DIR"
cp codemirror.min.js "$OUT_DIR/"

echo "==> Done! Bundle at $OUT_DIR/codemirror.min.js ($(wc -c < codemirror.min.js | tr -d ' ') bytes)"
