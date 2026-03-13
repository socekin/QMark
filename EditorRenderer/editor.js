// 从全局对象 CM 获取 CodeMirror 模块（由 codemirror.min.js IIFE 注入 window.CM）
const {EditorView, EditorState, basicSetup, keymap, markdown, markdownLanguage, languages, HighlightStyle, syntaxHighlighting, tags} = window.CM;

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

// ── 语法高亮主题（匹配 MarkEdit GitHub Light/Dark） ──
const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

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

const activeHighlight = isDark ? darkHighlight : lightHighlight;

// ── Initialize CodeMirror ──
const editor = new EditorView({
    parent: document.getElementById("editor"),
    state: EditorState.create({
        doc: "",
        extensions: [
            basicSetup,
            syntaxHighlighting(activeHighlight),
            markdown({base: markdownLanguage, codeLanguages: languages}),
            markdownKeymap,
            EditorView.lineWrapping,
            EditorView.updateListener.of((update) => {
                if (update.docChanged && !suppressChangeNotification) {
                    notifyContentChanged(update.state.doc.toString());
                }
            }),
            EditorView.theme({
                "&": {
                    height: "100%",
                    backgroundColor: isDark ? "#0d1117" : "#ffffff",
                    color: isDark ? "#c9d1d9" : "#24292f",
                },
                ".cm-scroller": {overflow: "auto"},
                ".cm-gutters": {
                    backgroundColor: isDark ? "#0d1117" : "#ffffff",
                    color: isDark ? "#6e7681" : "#8c959f",
                    borderRight: isDark ? "1px solid #30363d" : "1px solid #d0d7de",
                },
                ".cm-activeLineGutter": {
                    backgroundColor: isDark ? "#6e76811a" : "#eaeef27f",
                },
                ".cm-activeLine": {
                    backgroundColor: isDark ? "#6e76811a" : "#eaeef27f",
                },
                ".cm-cursor, .cm-dropCursor": {
                    borderLeftColor: isDark ? "#58a6ff" : "#0a69da",
                },
                "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
                    background: isDark ? "#264f78" : "#add6ff",
                },
                "> .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
                    background: isDark ? "#264f78" : "#add6ff",
                },
                ".cm-content ::selection": {
                    background: isDark ? "#264f78" : "#add6ff",
                },
                ".cm-selectionMatch": {
                    background: isDark ? "#3fb95040" : "#4ac26b40",
                },
            }, {dark: isDark}),
        ],
    }),
});

setupScrollSync(editor);

// ── Swift → JS API ──
// These functions are called via WKWebView.callAsyncJavaScript()

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
