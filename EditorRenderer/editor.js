// 从全局对象 CM 获取 CodeMirror 模块（由 codemirror.min.js IIFE 注入 window.CM）
const {EditorView, EditorState, Compartment, basicSetup, keymap, markdown, markdownLanguage, languages, HighlightStyle, syntaxHighlighting, tags} = window.CM;

// ── Debounce helper ──
function debounce(fn, ms) {
    let timer = null;
    return (...args) => {
        clearTimeout(timer);
        timer = setTimeout(() => fn(...args), ms);
    };
}

// ── Swift bridge helpers ──
function postMessage(name, body) {
    try {
        window.webkit.messageHandlers[name].postMessage(body);
    } catch (e) {
        // Not in WKWebView context (e.g., testing in browser)
        console.log(`[bridge] ${name}:`, body);
    }
}

const notifyContentChanged = debounce((text) => {
    postMessage("contentChanged", text);
}, 300);

// ── Markdown keyboard shortcuts (⌘B, ⌘I, ⌘K) ──
function wrapSelection(view, wrapper) {
    const {from, to} = view.state.selection.main;
    const selected = view.state.sliceDoc(from, to);
    const replacement = wrapper + selected + wrapper;
    view.dispatch({
        changes: {from, to, insert: replacement},
        selection: {anchor: from + wrapper.length, head: to + wrapper.length}
    });
    return true;
}

function insertLink(view) {
    const {from, to} = view.state.selection.main;
    const selected = view.state.sliceDoc(from, to);
    const replacement = `[${selected}](url)`;
    view.dispatch({
        changes: {from, to, insert: replacement},
        selection: {anchor: from + selected.length + 3, head: from + selected.length + 6}
    });
    return true;
}

const markdownKeymap = keymap.of([
    {key: "Mod-b", run: (view) => wrapSelection(view, "**")},
    {key: "Mod-i", run: (view) => wrapSelection(view, "*")},
    {key: "Mod-k", run: (view) => insertLink(view)},
]);

// ── Scroll sync ──
function setupScrollSync(view) {
    const scrollDOM = view.scrollDOM;
    scrollDOM.addEventListener("scroll", () => {
        const scrollTop = scrollDOM.scrollTop;
        const scrollHeight = scrollDOM.scrollHeight - scrollDOM.clientHeight;
        const percentage = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
        postMessage("scrollChanged", percentage);
    });
}

// ── Swift → JS API state ──
let suppressChangeNotification = false;

// ── 语法高亮定义（匹配 MarkEdit GitHub Light/Dark） ──
const lightHighlight = HighlightStyle.define([
    {tag: tags.heading, color: "#0550ae", fontWeight: "bold"},
    {tag: tags.strong, fontWeight: "bold"},
    {tag: tags.emphasis, fontStyle: "italic"},
    {tag: tags.strikethrough, textDecoration: "line-through"},
    {tag: tags.link, color: "#0a3069", textDecoration: "underline"},
    {tag: tags.url, color: "#24292f"},
    {tag: tags.quote, color: "#116329", fontStyle: "italic"},
    {tag: [tags.list], color: "#953800"},
    {tag: tags.monospace, backgroundColor: "#afb8c133"},
    {tag: [tags.meta, tags.comment], color: "#6e7781", fontStyle: "italic"},
    {tag: tags.keyword, color: "#cf222e"},
    {tag: [tags.string, tags.special(tags.string), tags.regexp, tags.escape], color: "#0a3069"},
    {tag: [tags.function(tags.variableName), tags.function(tags.propertyName)], color: "#8250df"},
    {tag: [tags.literal, tags.inserted, tags.tagName], color: "#116329"},
    {tag: [tags.deleted, tags.macroName], color: "#82071e"},
    {tag: [tags.className, tags.definition(tags.propertyName), tags.definition(tags.typeName)], color: "#953800"},
    {tag: tags.invalid, color: "#ff0000"},
]);

const darkHighlight = HighlightStyle.define([
    {tag: tags.heading, color: "#79c0ff", fontWeight: "bold"},
    {tag: tags.strong, fontWeight: "bold"},
    {tag: tags.emphasis, fontStyle: "italic"},
    {tag: tags.strikethrough, textDecoration: "line-through"},
    {tag: tags.link, color: "#a5d6ff", textDecoration: "underline"},
    {tag: tags.url, color: "#c9d1d9"},
    {tag: tags.quote, color: "#7ee787", fontStyle: "italic"},
    {tag: [tags.list], color: "#ffa657"},
    {tag: tags.monospace, backgroundColor: "#484f5866"},
    {tag: [tags.meta, tags.comment], color: "#8b949e", fontStyle: "italic"},
    {tag: tags.keyword, color: "#ff7b72"},
    {tag: [tags.string, tags.special(tags.string), tags.regexp, tags.escape], color: "#a5d6ff"},
    {tag: [tags.function(tags.variableName), tags.function(tags.propertyName)], color: "#d2a8ff"},
    {tag: [tags.literal, tags.inserted, tags.tagName], color: "#7ee787"},
    {tag: [tags.deleted, tags.macroName], color: "#ffa198"},
    {tag: [tags.className, tags.definition(tags.propertyName), tags.definition(tags.typeName)], color: "#ffa657"},
    {tag: tags.invalid, color: "#ff0000"},
]);

// ── 编辑器主题构建函数 ──
function buildEditorTheme(dark) {
    return EditorView.theme({
        "&": {
            height: "100%",
            backgroundColor: dark ? "#0d1117" : "#ffffff",
            color: dark ? "#c9d1d9" : "#24292f",
        },
        ".cm-scroller": {overflow: "auto", colorScheme: dark ? "dark" : "light"},
        ".cm-gutters": {
            backgroundColor: dark ? "#0d1117" : "#ffffff",
            color: dark ? "#6e7681" : "#8c959f",
            borderRight: dark ? "1px solid #30363d" : "1px solid #d0d7de",
        },
        ".cm-activeLineGutter": {
            backgroundColor: dark ? "#6e76811a" : "#eaeef27f",
        },
        ".cm-activeLine": {
            backgroundColor: dark ? "#6e76811a" : "#eaeef27f",
        },
        ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: dark ? "#58a6ff" : "#0a69da",
        },
        "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
            background: dark ? "#264f78" : "#add6ff",
        },
        "> .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
            background: dark ? "#264f78" : "#add6ff",
        },
        ".cm-content ::selection": {
            background: dark ? "#264f78" : "#add6ff",
        },
        ".cm-selectionMatch": {
            background: dark ? "#3fb95040" : "#4ac26b40",
        },
    }, {dark: dark});
}

// ── 使用 Compartment 实现动态主题切换 ──
const themeCompartment = new Compartment();
const highlightCompartment = new Compartment();

let isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

// ── Initialize CodeMirror ──
const editor = new EditorView({
    parent: document.getElementById("editor"),
    state: EditorState.create({
        doc: "",
        extensions: [
            basicSetup,
            highlightCompartment.of(syntaxHighlighting(isDark ? darkHighlight : lightHighlight)),
            markdown({base: markdownLanguage, codeLanguages: languages}),
            markdownKeymap,
            EditorView.lineWrapping,
            EditorView.updateListener.of((update) => {
                if (update.docChanged && !suppressChangeNotification) {
                    notifyContentChanged(update.state.doc.toString());
                }
            }),
            themeCompartment.of(buildEditorTheme(isDark)),
        ],
    }),
});

setupScrollSync(editor);

// ── 监听系统主题切换，动态更新编辑器 ──
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
    isDark = e.matches;
    editor.dispatch({
        effects: [
            themeCompartment.reconfigure(buildEditorTheme(isDark)),
            highlightCompartment.reconfigure(syntaxHighlighting(isDark ? darkHighlight : lightHighlight)),
        ],
    });
});

// ── Swift → JS API ──
// These functions are called via WKWebView.callAsyncJavaScript()

window.setTheme = function(dark) {
    isDark = dark;
    editor.dispatch({
        effects: [
            themeCompartment.reconfigure(buildEditorTheme(isDark)),
            highlightCompartment.reconfigure(syntaxHighlighting(isDark ? darkHighlight : lightHighlight)),
        ],
    });
};

window.setContent = function(text) {
    suppressChangeNotification = true;
    editor.dispatch({
        changes: {from: 0, to: editor.state.doc.length, insert: text}
    });
    suppressChangeNotification = false;
};

window.getContent = function() {
    return editor.state.doc.toString();
};

// ── Notify Swift that editor is ready ──
postMessage("editorReady", true);
