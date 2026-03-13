// 从全局对象 CM 获取 CodeMirror 模块（由 codemirror.min.js IIFE 注入 window.CM）
const {EditorView, EditorState, basicSetup, keymap, markdown, markdownLanguage, languages} = window.CM;

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

// ── Initialize CodeMirror ──
const editor = new EditorView({
    parent: document.getElementById("editor"),
    state: EditorState.create({
        doc: "",
        extensions: [
            basicSetup,
            markdown({base: markdownLanguage, codeLanguages: languages}),
            markdownKeymap,
            EditorView.updateListener.of((update) => {
                if (update.docChanged && !suppressChangeNotification) {
                    notifyContentChanged(update.state.doc.toString());
                }
            }),
            EditorView.theme({
                "&": {height: "100%"},
                ".cm-scroller": {overflow: "auto"},
            }),
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
