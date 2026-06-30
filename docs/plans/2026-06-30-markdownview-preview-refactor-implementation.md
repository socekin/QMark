# MarkdownView Preview Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace QMark's Markdown preview and Quick Look rendering pipeline with a shared SwiftUI preview powered by `LiYanan2004/MarkdownView`, without Mermaid support in this phase.

**Architecture:** Keep the existing CodeMirror editor unchanged. Add a shared SwiftUI preview source folder that is compiled into both the main app and Quick Look extension. The main app and Quick Look should both render through `QMarkMarkdownPreview`, while the old web renderer assets remain in the repository for rollback.

**Tech Stack:** SwiftUI, AppKit, QuickLookUI, XcodeGen, Swift Package Manager, MarkdownView pinned to revision `82cf1bba9d2c5fdf52d895506e4142fcbbcfe157`.

---

## Task 1: Add the MarkdownView Package Dependency

**Files:**
- Modify: `project.yml`

**Step 1: Add the package declaration**

Add this top-level block after `options` and before `settings`:

```yaml
packages:
  MarkdownView:
    url: https://github.com/LiYanan2004/MarkdownView.git
    revision: 82cf1bba9d2c5fdf52d895506e4142fcbbcfe157
```

**Step 2: Link the package to the main app target**

Update the existing `QMark` dependencies:

```yaml
    dependencies:
      - target: QMarkQuickLook
      - package: MarkdownView
        product: MarkdownView
```

**Step 3: Link the package to the Quick Look target**

Add a dependencies block under `QMarkQuickLook`:

```yaml
    dependencies:
      - package: MarkdownView
        product: MarkdownView
```

**Step 4: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: command succeeds and updates `QMark.xcodeproj`.

**Step 5: Build to verify package resolution**

Run:

```bash
xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds, or only fails on a package declaration syntax issue. Fix `project.yml` before continuing.

**Step 6: Commit checkpoint**

```bash
git add project.yml QMark.xcodeproj
git commit -m "build: add MarkdownView package dependency"
```

## Task 2: Add the Shared Preview Source Folder

**Files:**
- Modify: `project.yml`
- Create: `QMarkShared/Preview/QMarkMarkdownPreview.swift`

**Step 1: Add `QMarkShared` to both targets**

Add the shared source folder to the `QMark` target sources:

```yaml
      - path: QMarkShared
        type: group
```

Add the same source folder to the `QMarkQuickLook` target sources:

```yaml
      - path: QMarkShared
        type: group
```

The shared folder must be compiled into both targets. Do not create a new framework target in this phase.

**Step 2: Create the shared preview view**

Create `QMarkShared/Preview/QMarkMarkdownPreview.swift`:

```swift
import AppKit
import SwiftUI
import MarkdownView

struct QMarkMarkdownPreview: View {
    let markdown: String
    let isDark: Bool
    let baseURL: URL?

    init(
        markdown: String,
        isDark: Bool = false,
        baseURL: URL? = nil
    ) {
        self.markdown = markdown
        self.isDark = isDark
        self.baseURL = baseURL
    }

    var body: some View {
        ScrollView {
            MarkdownReader(markdown) { parseResult in
                MarkdownView(parseResult)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .markdownMathRenderingEnabled()
            .markdownLinksUnderlined()
            .markdownTableStyle(.github)
            .markdownBlockQuoteStyle(.github)
            .markdownCodeBlockStyle(.default)
            .modifier(QMarkMarkdownBaseURLModifier(baseURL: baseURL))
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\.colorScheme, isDark ? .dark : .light)
        #if os(macOS)
        .textSelection(.enabled)
        #endif
    }
}

private struct QMarkMarkdownBaseURLModifier: ViewModifier {
    let baseURL: URL?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let baseURL {
            content.markdownBaseURL(baseURL)
        } else {
            content
        }
    }
}
```

**Step 3: Regenerate the project**

Run:

```bash
xcodegen generate
```

Expected: command succeeds and `QMarkShared/Preview/QMarkMarkdownPreview.swift` appears in both target source lists.

**Step 4: Build to verify shared source compilation**

Run:

```bash
xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds. If it fails in `QMarkMarkdownPreview`, fix the API usage before continuing.

**Step 5: Commit checkpoint**

```bash
git add project.yml QMark.xcodeproj QMarkShared/Preview/QMarkMarkdownPreview.swift
git commit -m "feat: add shared MarkdownView preview"
```

## Task 3: Replace the Main App Preview Surface

**Files:**
- Modify: `QMark/Preview/PreviewView.swift`
- Keep: `QMark/Preview/PreviewBridge.swift`
- Keep: `SharedRenderer/`

**Step 1: Replace the WebView wrapper with a SwiftUI view**

Replace `QMark/Preview/PreviewView.swift` with:

```swift
import AppKit
import SwiftUI

struct PreviewView: View {
    let markdown: String
    let scrollPercentage: CGFloat
    var isDark: Bool = false

    var body: some View {
        QMarkMarkdownPreview(
            markdown: markdown,
            isDark: isDark
        )
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}
```

Keep the `scrollPercentage` parameter for now so `ContentView` does not need a wider change. It is intentionally unused in this phase because the old percentage-based JavaScript bridge no longer exists.

**Step 2: Do not delete rollback files**

Leave these files in place:

- `QMark/Preview/PreviewBridge.swift`
- `SharedRenderer/template.html`
- `SharedRenderer/renderer.js`
- `SharedRenderer/libs/*`

They are unused after this task but should remain available until the MarkdownView preview is accepted.

**Step 3: Build**

Run:

```bash
xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 4: Manual app smoke test**

Run:

```bash
open build/Build/Products/Debug/QMark.app
```

Expected:

- App launches.
- Opening or creating a Markdown document shows the native preview.
- Editing text updates the preview.
- Links open in the system browser.
- Mermaid fences display as code blocks.

**Step 5: Commit checkpoint**

```bash
git add QMark/Preview/PreviewView.swift
git commit -m "feat: render app preview with MarkdownView"
```

## Task 4: Replace the Quick Look Renderer

**Files:**
- Modify: `QMarkQuickLook/PreviewViewController.swift`
- Keep: `QMarkQuickLook/Info.plist`
- Keep: `QMarkQuickLook/QMarkQuickLook.entitlements`

**Step 1: Replace the WebView implementation**

Replace `QMarkQuickLook/PreviewViewController.swift` with:

```swift
import Cocoa
import QuickLookUI
import SwiftUI

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        guard let markdownData = try? Data(contentsOf: url),
              let markdownText = String(data: markdownData, encoding: .utf8)
        else {
            handler(NSError(domain: "QMarkQuickLook", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot read file"
            ]))
            return
        }

        let preview = QMarkMarkdownPreview(
            markdown: markdownText,
            isDark: isDarkAppearance,
            baseURL: url.deletingLastPathComponent()
        )
        .environment(\.openURL, OpenURLAction { _ in
            .discarded
        })

        view = NSHostingView(rootView: preview)
        handler(nil)
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
```

Quick Look should discard link openings in this phase. Opening external links from an app extension has a different security and UX profile than the main app, so it should be revisited separately.

**Step 2: Build**

Run:

```bash
xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds with the Quick Look extension.

**Step 3: Manual Quick Look smoke test**

Run the app once so the extension is registered:

```bash
open build/Build/Products/Debug/QMark.app
```

Then use Finder Quick Look on sample files:

- `.md`
- `.markdown`
- `.mdx`
- `.rmd`
- `.mdown`
- `.mkd`

Expected:

- Quick Look opens without crashing.
- Markdown content renders through the native preview.
- Dark mode is readable.
- Mermaid fences display as code blocks.

**Step 4: Commit checkpoint**

```bash
git add QMarkQuickLook/PreviewViewController.swift
git commit -m "feat: render Quick Look previews with MarkdownView"
```

## Task 5: Final Verification and Cleanup Notes

**Files:**
- Modify if needed: `docs/plans/2026-06-30-markdownview-preview-refactor-design.md`
- Modify if needed: `docs/plans/2026-06-30-markdownview-preview-refactor-implementation.md`

**Step 1: Run formatting and diff checks**

Run:

```bash
git diff --check
```

Expected: no output.

**Step 2: Run the full Debug build**

Run:

```bash
xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

**Step 3: Run manual rendering checks**

Create or open a Markdown document containing:

````markdown
# Heading

This is **bold**, *italic*, and ~~struck through~~ text.

- [x] Completed task
- [ ] Pending task

| Name | Value |
| --- | --- |
| QMark | Native preview |

```swift
let value = "code"
```

Inline math: $E = mc^2$

```mermaid
graph TD
  A --> B
```
````

Expected:

- Heading, text styles, tasks, table, code block, and math render correctly.
- Mermaid displays as a code block.
- Preview remains responsive while editing.

**Step 4: Review rollback status**

Confirm these rollback assets still exist:

```bash
test -f QMark/Preview/PreviewBridge.swift
test -d SharedRenderer
```

Expected: both commands exit successfully.

**Step 5: Final commit checkpoint**

```bash
git add .
git commit -m "feat: migrate markdown preview to MarkdownView"
```

## Notes for Execution

- Do not remove `SharedRenderer` in this implementation.
- Do not implement Mermaid in this implementation.
- Do not change the CodeMirror editor.
- If the MarkdownView API changes before implementation starts, update the revision pin and rebuild the external package in isolation before editing QMark.
- If Quick Look fails only when signed or installed, separate extension registration/debugging from renderer integration before changing the preview architecture.
