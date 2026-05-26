/**
 * Cadence Help Widget
 * A floating chat assistant powered by Claude.
 * Self-contained — injects its own styles and DOM nodes.
 */
(function () {
  'use strict';

  // ── Styles ───────────────────────────────────────────────────────────────────
  const STYLES = `
    #cadence-help-btn {
      position: fixed;
      bottom: 1.5rem;
      right: 1.5rem;
      width: 52px;
      height: 52px;
      border-radius: 50%;
      background: var(--primary, #6366f1);
      color: #fff;
      border: none;
      cursor: pointer;
      font-size: 1.6rem;
      font-weight: 700;
      box-shadow: 0 4px 14px rgba(0,0,0,0.22);
      z-index: 9998;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
      padding: 0;
      line-height: 1;
    }
    #cadence-help-btn:hover {
      transform: scale(1.08);
      box-shadow: 0 6px 18px rgba(0,0,0,0.28);
    }
    #cadence-help-panel {
      position: fixed;
      bottom: 5.5rem;
      right: 1.5rem;
      width: 340px;
      max-width: calc(100vw - 2rem);
      height: 480px;
      max-height: calc(100vh - 7rem);
      background: var(--bg-card, #fff);
      border: 1px solid var(--border, #e5e7eb);
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.18);
      display: flex;
      flex-direction: column;
      z-index: 9999;
      overflow: hidden;
      transition: opacity 0.18s ease, transform 0.18s ease;
    }
    #cadence-help-panel.hw-hidden {
      opacity: 0;
      pointer-events: none;
      transform: translateY(10px);
    }
    .hw-header {
      padding: 0.8rem 0.9rem;
      background: var(--primary, #6366f1);
      color: #fff;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-weight: 600;
      font-size: 0.9rem;
      flex-shrink: 0;
    }
    .hw-header-title { flex: 1; }
    .hw-header-btn {
      background: none;
      border: none;
      color: rgba(255,255,255,0.75);
      cursor: pointer;
      font-size: 0.95rem;
      padding: 0.2rem 0.35rem;
      border-radius: 4px;
      line-height: 1;
      transition: color 0.1s, background 0.1s;
    }
    .hw-header-btn:hover {
      color: #fff;
      background: rgba(255,255,255,0.15);
    }
    .hw-messages {
      flex: 1;
      overflow-y: auto;
      padding: 0.7rem;
      display: flex;
      flex-direction: column;
      gap: 0.55rem;
    }
    .hw-msg {
      max-width: 90%;
      padding: 0.5rem 0.7rem;
      border-radius: 12px;
      font-size: 0.855rem;
      line-height: 1.48;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .hw-msg.hw-user {
      align-self: flex-end;
      background: var(--primary, #6366f1);
      color: #fff;
      border-bottom-right-radius: 3px;
    }
    .hw-msg.hw-bot {
      align-self: flex-start;
      background: var(--bg-secondary, #f3f4f6);
      color: var(--text-primary, #111827);
      border-bottom-left-radius: 3px;
    }
    .hw-msg.hw-bot.hw-streaming::after {
      content: '▋';
      animation: hw-blink 0.65s step-end infinite;
      margin-left: 1px;
    }
    @keyframes hw-blink { 0%,100%{opacity:1} 50%{opacity:0} }
    .hw-msg.hw-rendered { white-space: normal; }
    .hw-msg p { margin: 0; }
    .hw-msg p + p { margin-top: 0.35rem; }
    .hw-msg ul, .hw-msg ol { margin: 0.2rem 0; padding-left: 1.1rem; }
    .hw-msg li { margin: 0.1rem 0; }
    .hw-msg strong { font-weight: 700; }
    .hw-msg em { font-style: italic; }
    .hw-msg code {
      font-family: monospace;
      font-size: 0.85em;
      background: rgba(0,0,0,0.07);
      padding: 0.1em 0.25em;
      border-radius: 3px;
    }
    .hw-msg.hw-system {
      align-self: center;
      background: none;
      color: var(--text-secondary, #6b7280);
      font-size: 0.8rem;
      font-style: italic;
      padding: 0.2rem 0;
    }
    .hw-input-row {
      padding: 0.6rem;
      border-top: 1px solid var(--border, #e5e7eb);
      display: flex;
      gap: 0.4rem;
      flex-shrink: 0;
    }
    #hw-input {
      flex: 1;
      padding: 0.5rem 0.65rem;
      border: 1px solid var(--border, #e5e7eb);
      border-radius: 8px;
      font-size: 0.855rem;
      resize: none;
      background: var(--bg-secondary, #f9fafb);
      color: var(--text-primary, #111827);
      font-family: inherit;
      outline: none;
      min-height: 36px;
      max-height: 96px;
      overflow-y: auto;
      line-height: 1.4;
    }
    #hw-input:focus { border-color: var(--primary, #6366f1); }
    #hw-send {
      width: 36px;
      height: 36px;
      flex-shrink: 0;
      background: var(--primary, #6366f1);
      color: #fff;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font-size: 1.1rem;
      line-height: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: opacity 0.15s;
      padding: 0;
    }
    #hw-send:disabled { opacity: 0.45; cursor: default; }
  `;

  // ── State ────────────────────────────────────────────────────────────────────
  const history = []; // { role: 'user'|'assistant', content: string }
  let streaming = false;

  // ── Bootstrap ────────────────────────────────────────────────────────────────
  function init() {
    injectStyles();
    buildDOM();
  }

  function injectStyles() {
    const el = document.createElement('style');
    el.id = 'cadence-help-styles';
    el.textContent = STYLES;
    document.head.appendChild(el);
  }

  function buildDOM() {
    // Floating button
    const btn = document.createElement('button');
    btn.id = 'cadence-help-btn';
    btn.title = 'Help';
    btn.setAttribute('aria-label', 'Open help chat');
    btn.textContent = '?';
    btn.addEventListener('click', togglePanel);

    // Chat panel
    const panel = document.createElement('div');
    panel.id = 'cadence-help-panel';
    panel.className = 'hw-hidden';
    panel.setAttribute('role', 'dialog');
    panel.setAttribute('aria-label', 'Cadence help');
    panel.innerHTML = `
      <div class="hw-header">
        <span class="hw-header-title">🎵 Cadence Help</span>
        <button class="hw-header-btn" id="hw-clear" title="Clear chat">🗑</button>
        <button class="hw-header-btn" id="hw-close" title="Close">✕</button>
      </div>
      <div class="hw-messages" id="hw-messages">
        <div class="hw-msg hw-system">Ask me anything about using Cadence!</div>
      </div>
      <div class="hw-input-row">
        <textarea id="hw-input" placeholder="Ask a question…" rows="1" aria-label="Your question"></textarea>
        <button id="hw-send" aria-label="Send">↑</button>
      </div>
    `;

    document.body.appendChild(btn);
    document.body.appendChild(panel);

    document.getElementById('hw-close').addEventListener('click', closePanel);
    document.getElementById('hw-clear').addEventListener('click', clearChat);
    document.getElementById('hw-send').addEventListener('click', sendMessage);

    const input = document.getElementById('hw-input');
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
    input.addEventListener('input', () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 96) + 'px';
    });
  }

  // ── Panel controls ───────────────────────────────────────────────────────────
  function togglePanel() {
    const panel = document.getElementById('cadence-help-panel');
    if (panel.classList.contains('hw-hidden')) {
      panel.classList.remove('hw-hidden');
      document.getElementById('hw-input').focus();
    } else {
      closePanel();
    }
  }

  function closePanel() {
    document.getElementById('cadence-help-panel').classList.add('hw-hidden');
  }

  function clearChat() {
    history.length = 0;
    const msgs = document.getElementById('hw-messages');
    msgs.innerHTML = '<div class="hw-msg hw-system">Ask me anything about using Cadence!</div>';
  }

  // ── Markdown renderer ────────────────────────────────────────────────────────
  function renderMarkdown(text) {
    function esc(s) {
      return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
    function inline(s) {
      return esc(s)
        .replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>')
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.+?)\*/g, '<em>$1</em>')
        .replace(/`([^`]+)`/g, '<code>$1</code>');
    }
    return text.trim().split(/\n{2,}/).map(block => {
      const lines = block.split('\n').filter(l => l.trim());
      if (!lines.length) return '';
      if (lines.length === 1 && /^#{1,3}\s/.test(lines[0])) {
        return '<p><strong>' + inline(lines[0].replace(/^#{1,3}\s+/, '')) + '</strong></p>';
      }
      if (lines.every(l => /^\s*[-*]\s/.test(l))) {
        return '<ul>' + lines.map(l => '<li>' + inline(l.replace(/^\s*[-*]\s+/, '')) + '</li>').join('') + '</ul>';
      }
      if (lines.every(l => /^\s*\d+\.\s/.test(l))) {
        return '<ol>' + lines.map(l => '<li>' + inline(l.replace(/^\s*\d+\.\s+/, '')) + '</li>').join('') + '</ol>';
      }
      return '<p>' + lines.map(l => /^#{1,3}\s/.test(l) ? '<strong>' + inline(l.replace(/^#{1,3}\s+/, '')) + '</strong>' : inline(l)).join('<br>') + '</p>';
    }).join('');
  }

  // ── Messaging ────────────────────────────────────────────────────────────────
  function appendMessage(type, text, isStreaming) {
    const msgs = document.getElementById('hw-messages');
    const div = document.createElement('div');
    div.className = `hw-msg hw-${type}${isStreaming ? ' hw-streaming' : ''}`;
    div.textContent = text;
    msgs.appendChild(div);
    msgs.scrollTop = msgs.scrollHeight;
    return div;
  }

  async function sendMessage() {
    if (streaming) return;

    const input = document.getElementById('hw-input');
    const text = input.value.trim();
    if (!text) return;

    input.value = '';
    input.style.height = 'auto';
    document.getElementById('hw-send').disabled = true;

    appendMessage('user', text);
    history.push({ role: 'user', content: text });

    streaming = true;
    const botDiv = appendMessage('bot', '', true);

    try {
      const res = await fetch('/api/help', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: history.slice(-10) }),
      });

      if (!res.ok) throw new Error(`Server error ${res.status}`);

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buf = '';
      let fullText = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });

        const lines = buf.split('\n');
        buf = lines.pop(); // hold incomplete line

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const payload = line.slice(6);
          if (payload === '[DONE]') continue;
          try {
            const parsed = JSON.parse(payload);
            if (parsed.text) {
              fullText += parsed.text;
              botDiv.textContent = fullText;
              document.getElementById('hw-messages').scrollTop =
                document.getElementById('hw-messages').scrollHeight;
            }
          } catch {
            // ignore malformed SSE chunks
          }
        }
      }

      botDiv.classList.remove('hw-streaming');
      botDiv.classList.add('hw-rendered');
      botDiv.innerHTML = renderMarkdown(fullText);
      document.getElementById('hw-messages').scrollTop =
        document.getElementById('hw-messages').scrollHeight;
      history.push({ role: 'assistant', content: fullText });
    } catch {
      botDiv.textContent = 'Sorry, something went wrong. Please try again.';
      botDiv.classList.remove('hw-streaming');
      // Remove the failed user turn from history so the conversation stays consistent
      history.pop();
    } finally {
      streaming = false;
      document.getElementById('hw-send').disabled = false;
      document.getElementById('hw-input').focus();
    }
  }

  // ── Init ─────────────────────────────────────────────────────────────────────
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
