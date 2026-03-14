'use strict';

let md;

function initRenderer() {
    md = window.markdownit({
        html: true,
        linkify: true,
        typographer: true,
        highlight: function (str, lang) {
            if (lang === 'mermaid') {
                return '';
            }
            if (lang && hljs.getLanguage(lang)) {
                try {
                    return '<pre class="hljs"><code>' +
                        hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
                        '</code></pre>';
                } catch (_) {}
            }
            return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
        }
    });

    // Load plugins
    md.use(window.markdownitFootnote);
    md.use(window.markdownitSub);
    md.use(window.markdownitSup);
    md.use(window.markdownitMark);
    md.use(window.markdownitDeflist);
    md.use(window.markdownitTaskLists, { enabled: true });
    md.use(window.texmath, { engine: katex, delimiters: 'dollars' });
    md.use(window.markdownItAnchor);
    md.use(window.markdownItTocDoneRight);

    // Mermaid init
    mermaid.initialize({
        startOnLoad: false,
        theme: 'default',
        securityLevel: 'strict'
    });
}

async function renderMarkdown(text) {
    const contentEl = document.getElementById('content');

    // 1. markdown-it parse (highlight.js and KaTeX done synchronously)
    const html = md.render(text);

    // 2. Insert into DOM
    contentEl.innerHTML = html;

    // 3. Mermaid post-processing
    const mermaidBlocks = contentEl.querySelectorAll('pre > code.language-mermaid');
    for (const block of mermaidBlocks) {
        const pre = block.parentElement;
        const div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = block.textContent;
        pre.replaceWith(div);
    }

    // 4. Render Mermaid diagrams
    const mermaidDivs = contentEl.querySelectorAll('.mermaid');
    if (mermaidDivs.length > 0) {
        try {
            await mermaid.run({ querySelector: '.mermaid' });
        } catch (e) {
            console.error('Mermaid rendering error:', e);
        }
    }

    // 5. Notify Swift rendering complete
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.renderComplete) {
        window.webkit.messageHandlers.renderComplete.postMessage({
            height: document.documentElement.scrollHeight
        });
    }
}

// Get current scroll percentage
function getScrollPercentage() {
    const scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
    const scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    return scrollHeight > 0 ? scrollTop / scrollHeight : 0;
}

// Set scroll percentage
function setScrollPercentage(percentage) {
    const scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    const scrollTop = scrollHeight * percentage;
    window.scrollTo({ top: scrollTop, behavior: 'auto' });
}
