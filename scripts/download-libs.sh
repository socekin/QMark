#!/bin/bash
set -euo pipefail

LIBS_DIR="SharedRenderer/libs"
mkdir -p "$LIBS_DIR/fonts"

# markdown-it core
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js" -o "$LIBS_DIR/markdown-it.min.js"

# markdown-it plugins
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-footnote@4.0.0/dist/markdown-it-footnote.min.js" -o "$LIBS_DIR/markdown-it-footnote.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-sub@2.0.0/dist/markdown-it-sub.min.js" -o "$LIBS_DIR/markdown-it-sub.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-sup@2.0.0/dist/markdown-it-sup.min.js" -o "$LIBS_DIR/markdown-it-sup.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-mark@4.0.0/dist/markdown-it-mark.min.js" -o "$LIBS_DIR/markdown-it-mark.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-deflist@3.0.0/dist/markdown-it-deflist.min.js" -o "$LIBS_DIR/markdown-it-deflist.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2.1.1/dist/markdown-it-task-lists.min.js" -o "$LIBS_DIR/markdown-it-task-lists.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-texmath@1.0.0/texmath.js" -o "$LIBS_DIR/markdown-it-texmath.js"

# KaTeX
curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js" -o "$LIBS_DIR/katex.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css" -o "$LIBS_DIR/katex.min.css"
# KaTeX fonts
for font in KaTeX_Main-Regular KaTeX_Main-Bold KaTeX_Main-Italic KaTeX_Math-Italic KaTeX_Size1-Regular KaTeX_Size2-Regular KaTeX_Size3-Regular KaTeX_Size4-Regular KaTeX_AMS-Regular KaTeX_Caligraphic-Regular KaTeX_Fraktur-Regular KaTeX_SansSerif-Regular KaTeX_Script-Regular KaTeX_Typewriter-Regular; do
    curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/fonts/${font}.woff2" -o "$LIBS_DIR/fonts/${font}.woff2"
done

# TOC (markdown-it-anchor + markdown-it-toc-done-right)
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-anchor@9.2.0/dist/markdownItAnchor.umd.js" -o "$LIBS_DIR/markdown-it-anchor.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-toc-done-right@4.2.0/dist/markdownItTocDoneRight.umd.js" -o "$LIBS_DIR/markdown-it-toc-done-right.min.js"

# Mermaid
curl -sL "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js" -o "$LIBS_DIR/mermaid.min.js"

# highlight.js
curl -sL "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.11.1/highlight.min.js" -o "$LIBS_DIR/highlight.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.11.1/styles/github.min.css" -o "$LIBS_DIR/github.min.css"
curl -sL "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.11.1/styles/github-dark.min.css" -o "$LIBS_DIR/github-dark.min.css"

echo "All libraries downloaded to $LIBS_DIR"
