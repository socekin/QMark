# QMark 编辑器 V2 — CodeMirror 6 方案设计文档

## 背景

原始设计采用 NSTextView（通过 NSViewRepresentable 嵌入 SwiftUI）作为编辑器。经过多轮实现和调试，NSTextView 在 SwiftUI 的 HSplitView 中存在无法解决的布局问题——text container 初始宽度为 0，导致文本无法渲染。

本文档描述将编辑器从 NSTextView 替换为 WKWebView + CodeMirror 6 的设计方案。其余模块（预览、QuickLook、SharedRenderer）保持不变。

### 参考

- [MarkEdit](https://github.com/MarkEdit-app/MarkEdit) — 3.8k 星的 macOS Markdown 编辑器，采用 WKWebView + CodeMirror 6 架构
- [原始设计文档](./2026-03-13-qmark-design.md) — 除编辑器模块外的需求保持不变

---

## 架构

```
QMark.xcodeproj
├── QMark (主应用)
│   ├── 文档模型              — ReferenceFileDocument，持有 @Published var text: String
│   ├── 编辑器模块            — WKWebView + CodeMirror 6
│   ├── 预览模块              — WKWebView + markdown-it（不变）
│   └── 共享渲染引擎          — HTML/CSS/JS 资源（不变）
│
├── EditorRenderer/          — 编辑器专用资源（新增）
│   ├── editor.html          — 加载 CodeMirror 的 HTML 模板
│   ├── editor.js            — CodeMirror 初始化 + Swift 桥接
│   ├── editor.css           — 编辑器样式（字体、行高、主题）
│   └── libs/
│       └── codemirror.min.js — CodeMirror 6 打包 bundle
│
├── SharedRenderer/          — 预览 + QuickLook 共用（不变）
│
└── QMarkQuickLook (扩展)    — 不变
```

### 资源共享机制

- `EditorRenderer/` 位于项目根目录（与 `QMark/`、`SharedRenderer/` 同级），仅被主应用 target 包含（QuickLook 不需要编辑器）
- `SharedRenderer/` 同时被主应用和 QuickLook target 包含（不变）
- 两个目录平级，结构对称

---

## 文档模型变化

`MarkdownDocument` 从 NSTextStorage 改为 String：

```swift
final class MarkdownDocument: ReferenceFileDocument, @unchecked Sendable {
    @Published var text: String

    static var readableContentTypes: [UTType] { /* 不变 */ }
    static var writableContentTypes: [UTType] { /* 不变 */ }

    init() { self.text = "" }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }

    func snapshot(contentType: UTType) throws -> String { text }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot.data(using: .utf8)!)
    }
}
```

变化点：
- `NSTextStorage` → `@Published var text: String`
- `ReferenceFileDocument` 继承 `ObservableObject`，`@Published text` 变化时自动触发 `objectWillChange`，SwiftUI 据此检测文档变更并触发 auto-save（替代之前 NSTextStorage 的变更通知机制）
- UTType 定义不变
- `ReferenceFileDocument` 协议不变
- 撤销管理由 CodeMirror history 扩展处理

---

## 编辑器模块

### EditorRenderer 资源文件

| 文件 | 职责 |
|------|------|
| `editor.html` | HTML 模板，加载 CodeMirror bundle + 自定义 JS/CSS |
| `editor.js` | CodeMirror 初始化、扩展配置、Swift ↔ JS 桥接函数 |
| `editor.css` | 编辑器样式：等宽字体 14pt、行高 1.5、内边距 16px、亮暗主题 |
| `libs/codemirror.min.js` | CodeMirror 6 打包 bundle |

### CodeMirror 6 扩展配置

```
- @codemirror/lang-markdown    — Markdown 语法高亮
- @codemirror/language-data    — 代码块内嵌语言高亮
- codemirror (meta-package)    — 包含 view、state、commands、search、history、autocomplete
```

打包为单个 `codemirror.min.js`（用 esbuild），预估 150-200KB。

其中 `codemirror` meta-package 已包含 `lineNumbers()` 扩展，编辑器默认启用行号显示（保持原始设计需求）。

### Swift ↔ JS 桥接

| 方向 | 方法 | 用途 |
|------|------|------|
| Swift → JS | `callAsyncJavaScript("setContent", arguments: ["text": ...])` | 打开文件时设置编辑器内容 |
| Swift → JS | `callAsyncJavaScript("getContent")` | 保存时获取当前内容 |
| JS → Swift | `WKScriptMessageHandler("editorReady")` | 编辑器初始化完成通知 |
| JS → Swift | `WKScriptMessageHandler("contentChanged")` | 编辑时实时通知文本变化 |
| JS → Swift | `WKScriptMessageHandler("scrollChanged")` | 编辑器滚动位置变化 |

### 数据流

```
用户编辑
  → CodeMirror updateListener
  → JS 侧防抖 300ms
  → JS 发 contentChanged 消息（携带全文）
  → Swift Coordinator 接收
  → 更新 document.text（触发 auto-save）
  → 调用 onTextChange 回调更新 @State markdownText
  → PreviewView 收到新 markdownText
  → callAsyncJavaScript 渲染预览
```

防抖在 JS 侧（`editor.js` 中的 `updateListener`）执行，避免大文件时每次按键都跨 bridge 传输全文。Swift 侧收到消息后直接更新，不再额外防抖。

### EditorView (Swift 侧)

```swift
struct EditorView: NSViewRepresentable {
    @ObservedObject var document: MarkdownDocument
    var onTextChange: ((String) -> Void)?
    var onScrollChange: ((CGFloat) -> Void)?

    // makeNSView: 创建 WKWebView，加载 editor.html
    // updateNSView: 如果 document.text 被外部修改（如 revert），调用 setContent
    // Coordinator: WKScriptMessageHandler，处理 editorReady / contentChanged / scrollChanged
}
```

与 PreviewView 结构对称。

### 快捷键

- ⌘B / ⌘I / ⌘K → `editor.js` 中通过 CodeMirror keymap 注册
- ⌘Z / ⌘⇧Z → CodeMirror history 扩展处理
- ⌘F → CodeMirror search 扩展处理（包含查找和替换功能，原始设计 YAGNI 中的"查找替换"因 CodeMirror 内置而自然获得，无额外开发成本）
- 所有快捷键在 WKWebView 内部处理，不需要 Swift 侧参与

### 排版参数

通过 `editor.css` 控制：
- 字体：等宽字体 14px（`font-family: ui-monospace, SF Mono, monospace`）
- 行高：1.5
- 内边距：16px

### 主题

`editor.css` 使用 `@media (prefers-color-scheme: dark/light)` 自动切换：
- 亮色：白底 + 深色文字（对应原 EditorTheme.light）
- 暗色：深底 + 浅色文字（对应原 EditorTheme.dark）
- WKWebView 自动跟随系统外观，不需要 Swift 侧通知

---

## 加载时序

1. `makeNSView` 创建 WKWebView，加载 `editor.html`
2. HTML 加载完成 → CodeMirror 初始化 → JS 发 `editorReady` 消息
3. Coordinator 收到 `editorReady` → 调用 `setContent(document.text)` 设置初始内容
4. 如果 `editorReady` 之前 `updateNSView` 被调用，缓存内容待就绪后发送

---

## CodeMirror 打包

### 打包脚本 `scripts/build-editor.sh`

```
1. 创建临时目录
2. npm init + 安装 CodeMirror 依赖
3. 创建 entry.js（import 所有模块，export 到 window）
4. esbuild 打包为 EditorRenderer/libs/codemirror.min.js
5. 清理临时目录
```

npm 依赖：
```
codemirror
@codemirror/lang-markdown
@codemirror/language-data
```

打包产物 commit 到 repo，日常开发不需要 Node.js 环境。

### Makefile 更新

```makefile
editor-libs:
	bash scripts/build-editor.sh
```

---

## Liquid Glass

- 窗口标题栏：macOS 26 上 `.windowStyle(.automatic)` 自动获得 Liquid Glass 效果（原始设计提到 `.glassEffect()` 修饰符，实际在 macOS 26 中标题栏默认即为 Liquid Glass，无需手动添加）
- 工具栏：`.toolbarBackgroundVisibility(.visible, for: .windowToolbar)` 呈现毛玻璃质感
- 内容区（WKWebView）保持不透明背景，符合 Apple HIG（Liquid Glass 用于控件和结构元素，不用于内容区）

---

## 文件变更清单

### 删除

| 文件 | 原因 |
|------|------|
| `QMark/Editor/MarkdownHighlighter.swift` | CodeMirror 内置语法高亮 |
| `QMark/Editor/EditorTheme.swift` | 改由 editor.css 控制 |
| `QMarkTests/EditorViewTests.swift` | 依赖已移除的 NSTextView/NSTextStorage API，需删除 |

### 重写

| 文件 | 变化 |
|------|------|
| `QMark/Editor/EditorView.swift` | NSTextView → WKWebView + CodeMirror |
| `QMark/MarkdownDocument.swift` | NSTextStorage → @Published String |
| `QMark/ContentView.swift` | 数据流调整 |

### 新增

| 文件 | 说明 |
|------|------|
| `EditorRenderer/editor.html` | 编辑器 HTML 模板 |
| `EditorRenderer/editor.js` | CodeMirror 初始化 + 桥接 |
| `EditorRenderer/editor.css` | 编辑器样式 |
| `EditorRenderer/libs/codemirror.min.js` | CodeMirror 6 bundle |
| `scripts/build-editor.sh` | CodeMirror 打包脚本 |

### 修改

| 文件 | 变化 |
|------|------|
| `project.yml` | 新增 EditorRenderer 资源引用 |

### 不变

| 文件 |
|------|
| `QMark/QMarkApp.swift` |
| `QMark/Preview/PreviewView.swift` |
| `QMark/Preview/PreviewBridge.swift` |
| `QMark/Info.plist` |
| `SharedRenderer/*` |
| `QMarkQuickLook/*` |

---

## 边界情况

- **WKWebView 加载时序**：Coordinator 维护 `isEditorReady` 标志，editorReady 前缓存待发送内容
- **文件保存**：contentChanged 更新 document.text，ReferenceFileDocument 机制自动触发 auto-save
- **大文件**：CodeMirror 6 虚拟化渲染（只渲染可见行），性能优于 NSTextView 全量布局
- **外观切换**：WKWebView + CSS media query 自动处理，无需 Swift 侧干预
- **⌘Z 与系统 Edit 菜单**：CodeMirror 在 WKWebView 内部处理，不集成系统 UndoManager（与 MarkEdit 行为一致）
- **滚动同步计算**：CodeMirror 使用虚拟化滚动，`editor.js` 通过 `EditorView.scrollDOM.scrollTop / (scrollHeight - clientHeight)` 计算滚动百分比，通过 `scrollChanged` 消息传给 Swift 侧

---

## 不做的事情（YAGNI）

保持原始设计文档中的 YAGNI 列表不变。本次变更仅替换编辑器实现方案，不增加新功能。
