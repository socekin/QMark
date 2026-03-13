# QMark — 极简 macOS Markdown 编辑器设计文档

## 概述

QMark 是一款极简的原生 macOS Markdown 应用，提供两大核心能力：

1. **QuickLook 预览** — 在 Finder 中按空格键即可完整渲染预览 Markdown 文件
2. **编辑 + 预览** — 打开文件后左侧编辑、右侧实时预览

### 设计原则

- 极简：单文件模式，无文件树、无标签页、无导出
- 原生：SwiftUI + AppKit，Liquid Glass 设计语言
- 完整渲染：GFM + LaTeX + Mermaid + 代码高亮 + 脚注 + TOC 等全面支持
- 一致性：App 预览与 QuickLook 使用同一套渲染引擎

### 目标用户

- 个人使用，追求极简高效
- 面向开发者群体，计划开源或上架 App Store

### 系统要求

- macOS 26 (Tahoe) 及以上
- 全面采用 Liquid Glass 设计规范
- 注意：Liquid Glass API 目前处于预览阶段，如正式版 API 有变化需跟进调整

---

## 架构

QMark 由两个 target 组成：

```
QMark.xcodeproj
├── QMark (主应用)           — SwiftUI Document-based App
│   ├── 编辑器模块            — NSTextView 封装，Markdown 语法高亮
│   ├── 预览模块              — WKWebView，markdown-it + 插件渲染
│   └── 共享渲染引擎          — HTML/CSS/JS 资源，App 和 QuickLook 共用
│
└── QMarkQuickLook (扩展)    — QuickLook Preview Extension
    └── 复用共享渲染引擎       — 同一套 HTML 模板和 JS 渲染管线
```

### 资源共享机制

`SharedRenderer/` 目录位于项目根目录（与 `QMark/` 和 `QMarkQuickLook/` 同级），通过 **Xcode target membership** 同时包含在两个 target 中。两个 target 编译时各自将这些文件拷贝到自己的 bundle 中，无需 App Group 或独立 Framework。

WKWebView 加载本地资源时使用 `loadFileURL(_:allowingReadAccessTo:)` 方法，`allowingReadAccessTo` 设为 SharedRenderer 目录在 bundle 中的路径，确保 CSS/JS 等子资源可正常加载。

### 技术选型

| 模块 | 技术 | 理由 |
|------|------|------|
| 应用框架 | SwiftUI + AppKit | macOS 26 可充分用 SwiftUI，AppKit 补充 NSTextView |
| 设计语言 | Liquid Glass | macOS 26 原生设计规范 |
| Markdown 解析 | markdown-it (JS) | 插件生态丰富，一套代码同时服务预览和 QuickLook |
| 数学公式 | KaTeX | 比 MathJax 快，离线可用 |
| 图表 | Mermaid.js | 业界标准 |
| 代码高亮 | highlight.js | 支持 190+ 语言 |
| 编辑器 | NSTextView | 原生文本编辑，参考 MarkEdit 的交互体验 |

### 参考项目

- **MarkEdit** (3.8k 星) — 编辑器交互体验参考
- **QLMarkdown** — QuickLook 扩展架构参考
- **MacDown** (9.7k 星) — 经典左右分栏布局参考

---

## 界面设计

### 主界面布局

等宽左右分栏布局：

- 左侧：Markdown 编辑器（NSTextView），占 50% 宽度
- 右侧：实时预览（WKWebView），占 50% 宽度
- 中间：分割线
- 编辑和预览之间滚动同步（单向：编辑器 → 预览，基于滚动百分比映射）

### Liquid Glass 应用

- 窗口标题栏使用 `.glassEffect()` 修饰符，呈现毛玻璃质感
- 文件名显示在标题栏中
- 后续工具栏按钮采用 Liquid Glass 风格
- 分栏分割线融入 Liquid Glass 视觉语言

### Dark / Light 模式

- 编辑器：NSTextView 配色跟随 `NSApp.effectiveAppearance`
- 预览：统一样式表 `style.css` 内使用 `@media (prefers-color-scheme: dark/light)` 自动切换亮暗主题
- 两侧同步响应系统外观变化，无需用户手动切换

---

## 模块详细设计

### 1. 编辑器模块 (Editor)

基于 NSTextView 封装的 SwiftUI 组件（NSViewRepresentable）：

- **语法高亮** — 使用 NSTextStorage 子类，实时着色 Markdown 语法（标题、粗体、斜体、代码、链接等各有不同颜色）
- **基本快捷键** — ⌘B 加粗、⌘I 斜体、⌘K 插入链接
- **行号显示** — NSRulerView 显示行号
- **自动适配主题** — 跟随系统 Dark/Light 切换编辑器配色
- **滚动同步** — 单向（编辑器 → 预览），基于滚动百分比映射，避免双向循环触发

**默认排版参数：**

- 字体：等宽字体（`NSFont.monospacedSystemFont`）
- 字号：系统默认（14pt）
- 行高：1.5 倍
- 内边距：左右 16pt

语法高亮方案：自己实现轻量的 Markdown 语法高亮器（基于正则匹配 + NSAttributedString），不引入额外依赖。后续如需更强编辑能力，可参考 MarkEdit 的方式演进。

实时预览触发：编辑器文本变化时，通过防抖（debounce ~300ms）触发预览更新，避免频繁渲染。

### 2. 预览模块 (Preview)

基于 WKWebView 封装的 SwiftUI 组件：

- 接收编辑器传入的 Markdown 原文
- 通过 `WKWebView.callAsyncJavaScript(_:arguments:)` 调用 renderer.js 渲染（每次传入全文重新渲染，非增量 diff）。使用 `callAsyncJavaScript` 而非 `evaluateJavaScript`，因为它通过 `arguments` 字典安全传递参数，避免 Markdown 内容中的特殊字符（反引号、引号、反斜杠）导致注入问题
- 渲染结果在 WKWebView 中展示

**PreviewBridge（Swift ↔ JS 通信）：**

- **Swift → JS 方向：** 通过 `callAsyncJavaScript(_:arguments:)` 将 Markdown 原文安全传入 WKWebView 触发渲染
- **JS → Swift 方向：** 通过 `WKScriptMessageHandler` 接收 JS 回调，用于：
  - 预览渲染完成通知（用于滚动同步时机）
  - 预览中链接点击事件（使用 `NSWorkspace.shared.open()` 在系统浏览器中打开外部链接）

### 3. 共享渲染引擎 (SharedRenderer)

App 预览和 QuickLook 共用的渲染资源：

```
SharedRenderer/
├── template.html                  — HTML 模板，注入 Markdown 内容
├── renderer.js                    — markdown-it 初始化 + 插件配置 + 渲染调用
├── style.css                      — 统一样式表，内含 @media (prefers-color-scheme) 自动切换亮/暗主题
├── libs/
│   ├── markdown-it.min.js         — Markdown 解析核心
│   ├── markdown-it-footnote.js    — 脚注
│   ├── markdown-it-sub.js         — 下标
│   ├── markdown-it-sup.js         — 上标
│   ├── markdown-it-mark.js        — 高亮标记
│   ├── markdown-it-deflist.js     — 定义列表
│   ├── markdown-it-task-lists.js  — 任务列表
│   ├── markdown-it-toc.js         — 目录生成
│   ├── markdown-it-texmath.js     — LaTeX 语法集成（将 $...$ / $$...$$ 路由到 KaTeX）
│   ├── katex.min.js + katex.css   — LaTeX 数学公式渲染
│   ├── mermaid.min.js             — 图表渲染（renderer.js 中将 language-mermaid 代码块路由到 Mermaid API）
│   └── highlight.min.js + 主题    — 代码语法高亮
```

**markdown-it 初始化配置：**

```javascript
const md = markdownit({ html: false, linkify: true, typographer: true, highlight: /* highlight.js */ });
```

`html` 设为 `false`，不允许 Markdown 中的原始 HTML 标签直接传递到渲染输出，避免用户打开的 .md 文件中包含 `<script>` 等标签带来的安全风险。markdown-it 内置支持删除线（`~~`），配合 `linkify: true` 实现自动链接，无需额外 GFM 插件。

渲染流程：

1. Swift 层将 Markdown 原文传入 WKWebView
2. `renderer.js` 调用 markdown-it 解析为 HTML（highlight.js 在解析阶段通过 `highlight` 选项同步处理代码块）
3. 将 HTML 插入 DOM
4. **DOM 后处理（异步）：** renderer.js 将所有 `<pre><code class="language-mermaid">` 元素替换为 `<div class="mermaid">` 容器，然后调用 `mermaid.run({ querySelector: '.mermaid' })` 渲染为 SVG 图表；KaTeX 由 markdown-it-texmath 在解析阶段已同步完成
5. 后处理完成后，通过 `WKScriptMessageHandler` 通知 Swift 层渲染完成（触发滚动同步）
6. CSS 根据系统 `prefers-color-scheme` 自动切换亮/暗主题

App 与 QuickLook 的调用方式不同：

- App 预览：编辑器内容变化时，通过 `callAsyncJavaScript()` 传入全文重新渲染
- QuickLook：一次性加载整个文件内容渲染

支持的 Markdown 语法：

- GitHub Flavored Markdown (GFM)：表格、任务列表、删除线、自动链接
- 数学公式：`$...$` 行内、`$$...$$` 块级（KaTeX 渲染）
- 图表：Mermaid 语法（flowchart, sequence, gantt, ER, pie 等）
- 代码高亮：190+ 语言（highlight.js）
- 脚注、上标、下标、高亮标记、定义列表
- 目录生成（TOC）

### 4. QuickLook 扩展 (QMarkQuickLook)

```
QMarkQuickLook/
├── PreviewViewController.swift    — 实现 QLPreviewingController 协议
│   └── preparePreviewOfFile(at:completionHandler:)
│       1. 读取 .md 文件内容
│       2. 加载 SharedRenderer 的 HTML 模板
│       3. 将 Markdown 内容注入模板
│       4. 在内嵌的 WKWebView 中加载 HTML（支持 JS 执行，Mermaid/KaTeX 可正常渲染）
│
└── Info.plist
    └── QLSupportedContentTypes: ["net.daringfireball.markdown", "com.qmark.mdx", "com.qmark.rmd", ...]
    └── Imported Type Declarations: 为 .mdx, .rmd, .mdown, .mkd 声明自定义 UTType
```

**UTType 策略：**

- `.md` / `.markdown` — 使用系统内置 UTType `net.daringfireball.markdown`
- `.mdx` / `.rmd` / `.mdown` / `.mkd` — 在主应用和 QuickLook 扩展的 Info.plist 中通过 **Imported Type Declarations** 声明自定义 UTType（如 `com.qmark.mdx`），conforming to `public.plain-text`
- Swift 代码中通过 `UTType` 扩展定义这些类型，供 `readableContentTypes` 使用

**QuickLook 渲染方式：** 采用 View Controller 模式（非 data-based QLPreviewReply），PreviewViewController 内嵌 WKWebView 作为预览视图。这样 JS 库可以正常执行，Mermaid 图表和 KaTeX 公式都能完整渲染。

**生命周期管理：** `preparePreviewOfFile(at:)` 调用时，先清空 WKWebView 现有内容再加载新文件，避免快速切换文件时短暂显示上一个文件的内容。

设计要点：

- 只做预览，不做编辑
- 与 App 预览渲染结果一致（共享渲染引擎）
- 离线可用（所有 JS/CSS 资源打包在扩展 bundle 内）
- 覆盖常见 Markdown 文件扩展名

### 5. 文档模型 (MarkdownDocument)

采用 **ReferenceFileDocument** 协议（class-based，遵循 `ObservableObject`），而非值类型的 `FileDocument`。理由：NSTextView 通过引用类型的 `NSTextStorage` 管理文本，使用 `ReferenceFileDocument` 可以直接持有对 `NSTextStorage` 的引用，避免值类型与引用类型之间的同步问题，并自然集成 NSTextView 自带的 `UndoManager`。

- `readableContentTypes` — 声明支持的 UTType（.md, .markdown, .mdown, .mkd, .mdx, .rmd，与 QuickLook 扩展保持一致）
- `init(from:)` — 读取文件内容为字符串，初始化 NSTextStorage
- `write(to:)` — 从 NSTextStorage 获取当前文本内容写入文件

应用通过 `DocumentGroup(newDocument:)` 自动获得：

- 打开 / 保存 / 另存为
- 打开最近文件
- 文件类型关联（注册为 .md 文件的可选打开方式）
- 从 Finder 双击或拖拽打开

**新建文件行为：** 创建一个空白的未保存 Markdown 文档，无默认模板内容。

---

## 项目结构

```
QMark/
├── QMark/                              # 主应用
│   ├── QMarkApp.swift                  # @main 入口
│   ├── MarkdownDocument.swift          # ReferenceFileDocument 文档模型
│   ├── ContentView.swift               # 左右分栏主界面
│   ├── Editor/
│   │   ├── EditorView.swift            # NSTextView 的 SwiftUI 封装
│   │   ├── MarkdownHighlighter.swift   # 语法高亮器
│   │   └── EditorTheme.swift           # 编辑器配色
│   └── Preview/
│       ├── PreviewView.swift           # WKWebView 的 SwiftUI 封装
│       └── PreviewBridge.swift         # Swift ↔ JS 通信
│
├── SharedRenderer/                     # 共享渲染资源（两个 target 共用）
│   ├── template.html
│   ├── renderer.js
│   ├── style.css
│   └── libs/                           # JS 库（全部本地打包）
│
├── QMarkQuickLook/                     # QuickLook 扩展
│   ├── PreviewViewController.swift
│   ├── QMarkQuickLook.entitlements
│   └── Info.plist
│
├── QMark.entitlements
└── QMark.xcodeproj
```

---

## 沙盒与签名

- 启用 **App Sandbox**（App Store 要求）
- **主应用 Entitlements（QMark.entitlements）：**
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.files.user-selected.read-write` — 读写用户选择的文件
  - `com.apple.security.network.client` — WKWebView 的 web content 进程在某些 macOS 版本下需要此权限才能正常工作（即使只加载本地资源）
- **QuickLook 扩展 Entitlements（QMarkQuickLook.entitlements）：**
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.network.client` — 同上，WKWebView 需要
  - 注意：扩展有独立的 entitlements 文件，不继承主应用配置
- 启用 **Hardened Runtime**

---

## 不做的事情（YAGNI）

以下功能明确不在当前范围内，后续按需添加：

- 导出功能（PDF、HTML、Word 等）
- 多标签页 / 文件树
- 可调分栏宽度 / 模式切换
- 设置界面（主题选择、字体配置等）
- 多光标、查找替换、代码折叠等高级编辑功能
- 图片拖拽插入
- 文件自动保存（依赖系统默认行为）
