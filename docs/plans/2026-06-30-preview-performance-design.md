# Preview Performance Design

## Goal

Optimize QMark for fast preview-first opening and responsive Quick Look rendering, with special focus on Markdown files below 5 MB. Editing can keep the current WKWebView and CodeMirror surface, but the editor must not be created during preview-only opening.

## Context

QMark currently opens documents with a split editor and preview layout. `ContentView` defaults `isEditorVisible` to `true`, so opening any file creates `EditorView`, which creates a `WKWebView` and loads the CodeMirror bundle before the user asks to edit. The preview uses `QMarkMarkdownPreview`, which wraps `MarkdownReader` and renders the whole Markdown string through `MarkdownView`.

This means the app currently pays three costs during a normal open:

- document read and UTF-8 decode;
- CodeMirror and WKWebView initialization;
- full Markdown parse and SwiftUI view layout.

Quick Look does not create CodeMirror, but it currently reads and decodes the file synchronously inside `preparePreviewOfFile`, then creates a full Markdown preview in one step.

## File Size Policy

QMark should optimize for the file sizes that are common for notes and generated Markdown reports:

| Size | Classification | Expected behavior |
| --- | --- | --- |
| `< 500 KB` | Normal | Preview opens and renders quickly. |
| `500 KB - 2 MB` | Medium | Preview remains immediate; complete rendering should be fast. |
| `2 MB - 5 MB` | Large | Primary optimization target. UI must stay responsive while full Markdown rendering completes. |
| `5 MB - 10 MB` | Very large | UI must not hang. Full rendering may take longer. |
| `> 10 MB` | Extreme | Best effort complete Markdown rendering; no plain-text fallback. |

There must be no plain-text fallback. If a file is large, QMark may stream the Markdown into the renderer and show progressive Markdown output, but the final result must remain the full `MarkdownView` rendering.

## Recommended Architecture

### 1. Preview-First Window Lifecycle

`ContentView` should default to preview-only mode:

- `isEditorVisible` starts as `false`.
- The toolbar editor button remains the entry point for editing.
- `EditorView` is only instantiated after the user opens editing.
- Closing the editor removes `EditorView` from the hierarchy and releases the WKWebView.

This is the highest-impact optimization because it removes CodeMirror startup work from the default open path.

### 2. Separate Document Text From Rendered Preview Text

The app should stop treating every editor text change as an immediate preview render request.

Use a preview model with two responsibilities:

- hold the latest document text;
- publish a debounced render source for the preview.

For normal files, a short debounce is enough. For large files, the debounce can be longer and any pending render task should be cancelled when newer text arrives.

Suggested behavior:

| Size | Preview update delay while editing |
| --- | --- |
| `< 500 KB` | 250 ms |
| `500 KB - 2 MB` | 500 ms |
| `2 MB - 5 MB` | 800 ms |
| `> 5 MB` | 1200 ms |

The document save path must still receive the latest text. The debounce only controls preview rendering, not document correctness.

### 3. Streaming Markdown Rendering For Initial Preview

MarkdownView 3 includes `StreamingMarkdownReader` and `StreamingMarkdownSource`. The current pinned version supports coalesced updates, detached parsing, and incremental parsing for append-style updates.

Use this for initial rendering in both the app preview and Quick Look:

- create a stable `StreamingMarkdownSource`;
- append chunks of the Markdown text into the source;
- call `finishStreaming()` after the last chunk so MarkdownView can perform its final full parse.

The user-visible output remains MarkdownView output. Streaming only changes delivery into the renderer.

For files below 2 MB, a single source assignment may be acceptable. For 2 MB and above, chunking avoids a single large main-thread render submission. A practical initial chunk size is 128 KB to 256 KB, adjusted after measurement.

### 4. Quick Look Asynchronous Preparation

`QMarkQuickLook/PreviewViewController.swift` should keep the root view stable and move file reading away from the main actor:

- `preparePreviewOfFile` installs the hosting view quickly;
- file data is loaded and decoded in a task;
- chunks are appended to a streaming source on the main actor;
- cancellation is handled when a new preview request arrives or the controller deinitializes.

The completion handler should be called after the preview view has been installed and the streaming task has started, not after every Markdown block is rendered. This keeps Quick Look responsive while still producing a full MarkdownView preview.

### 5. Scroll Synchronization

Use percentage-based sync as the first implementation. It is cheap, resilient to layout differences, and matches QMark's existing editor-to-preview bridge.

Add:

- editor-to-preview sync from CodeMirror scroll events;
- preview-to-editor sync from SwiftUI preview scroll geometry;
- a shared source guard in `ContentView` plus local renderer suppression to avoid feedback loops.

Keep the preview on the native SwiftUI `ScrollView` path used by MarkdownView. macOS 15 provides `ScrollPosition` and `onScrollGeometryChange`, which are enough for percentage-based offset observation and programmatic scrolling without wrapping MarkdownView content in an AppKit `NSScrollView`.

### 6. Instrumentation

Add lightweight `os.Logger` and `os_signpost` instrumentation around:

- app preview model load;
- first preview content submission;
- editor WKWebView creation;
- Quick Look prepare start;
- Quick Look file decode complete;
- Quick Look streaming complete.

The goal is not a permanent benchmark suite. The goal is to make performance regressions visible during local testing.

## Approaches Considered

### Approach A: Keep CodeMirror, Optimize Lifecycle And Rendering

This is the recommended path.

Pros:

- smallest implementation risk;
- keeps current editing behavior;
- directly improves open and Quick Look speed;
- aligns with MarkEdit's practical lesson that CodeMirror can be fast when initialization and bridge traffic are controlled.

Cons:

- the editor is still web-based;
- exact semantic scroll sync is deferred.

### Approach B: Deep MarkEdit-Style Editor Refactor

This would restructure QMark's editor into a more complete CoreEditor and native bridge architecture.

Pros:

- best long-term path if QMark remains CodeMirror-based;
- cleaner extension and bridge model.

Cons:

- much larger scope;
- does not directly improve Quick Look;
- unnecessary before fixing preview-first lifecycle and render scheduling.

### Approach C: Replace Editor With Native TextKit Editor

This would move the editor to a native library such as `swift-markdown-engine` or `STTextView`.

Pros:

- removes WKWebView from editing;
- improves native text editing story long term.

Cons:

- high migration risk;
- does not solve immediate preview rendering cost;
- would delay the current performance work.

## Success Criteria

- Opening a file in QMark does not instantiate `EditorView` or load `EditorRenderer/libs/codemirror.min.js` until the user enables editing.
- Files below 5 MB open in preview mode without visible app hang.
- Quick Look stays responsive for 5 MB files and progressively completes full Markdown rendering.
- A 10 MB file does not beachball Quick Look or the main app. Complete rendering may take several seconds.
- Editing still saves the latest document text.
- Preview updates are debounced while editing.
- Scroll sync works in both directions without feedback loops.

## Non-Goals

- No Mermaid rendering in this phase.
- No plain-text fallback for large files.
- No native editor replacement in this phase.
- No exact AST or heading-based scroll synchronization in this phase.
- No broad UI redesign.
