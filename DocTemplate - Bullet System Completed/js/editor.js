/* ==========================================================================
   Core Editor Engine Module with Auto-Pagination & Formatting
   ========================================================================== */

import { showToast } from './toast.js';

export class EditorEngine {
  constructor() {
    this.editorEl = document.getElementById('editor');
    this.pagesWrapper = document.getElementById('pages-wrapper');
    this.currentMode = 'editing';
    this.formatPainterActive = false;
    this.savedStyle = null;

    this.initListeners();
    this.updateStats();
    this.updateOutline();
    this.checkPagination();
  }

  initListeners() {
    if (!this.editorEl) return;

    this.editorEl.addEventListener('input', () => {
      this.updateStats();
      this.updateOutline();
      this.checkPagination();
    });

    this.editorEl.addEventListener('keyup', () => {
      this.updateStats();
      this.checkPagination();
    });
  }

  execute(command, value = null) {
    if (this.currentMode === 'viewing') {
      showToast('Document is in Viewing mode');
      return;
    }

    this.editorEl.focus();
    document.execCommand(command, false, value);
    this.updateStats();
    this.updateOutline();
    this.checkPagination();
  }

  setBlockStyle(tag) {
    this.execute('formatBlock', `<${tag}>`);
  }

  setFontFamily(font) {
    this.execute('fontName', font);
  }

  setFontSize(sizePt) {
    this.editorEl.focus();
    const selection = window.getSelection();
    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    if (range.collapsed) {
      // Set size for new typing
      const span = document.createElement('span');
      span.style.fontSize = `${sizePt}pt`;
      span.appendChild(document.createTextNode('\u200B')); // Zero width space
      range.insertNode(span);
      range.setStartAfter(span);
      range.setEndAfter(span);
      selection.removeAllRanges();
      selection.addRange(range);
    } else {
      const span = document.createElement('span');
      span.style.fontSize = `${sizePt}pt`;
      range.surroundContents(span);
    }
  }

  setTextColor(color) {
    this.execute('foreColor', color);
  }

  setHighlightColor(color) {
    this.execute('hiliteColor', color);
  }

  setAlignment(align) {
    if (align === 'left') this.execute('justifyLeft');
    else if (align === 'center') this.execute('justifyCenter');
    else if (align === 'right') this.execute('justifyRight');
    else if (align === 'justify') this.execute('justifyFull');
  }

  setMode(mode) {
    this.currentMode = mode;
    this.editorEl.setAttribute('contenteditable', mode !== 'viewing' ? 'true' : 'false');
    showToast(`Switched to ${mode.charAt(0).toUpperCase() + mode.slice(1)} mode`);
  }

  updateStats() {
    const text = this.editorEl.innerText || '';
    const words = text.trim() ? text.trim().split(/\s+/).length : 0;
    const chars = text.length;
    
    // Page calculation based on scroll height
    const scrollHeight = this.editorEl.scrollHeight;
    const pages = Math.max(1, Math.ceil(scrollHeight / 860));

    const statWordCount = document.getElementById('stat-word-count');
    if (statWordCount) {
      statWordCount.textContent = `Page 1 of ${pages}  •  ${words} words  •  ${chars} characters`;
    }

    const modalPages = document.getElementById('stat-modal-pages');
    const modalWords = document.getElementById('stat-modal-words');
    const modalChars = document.getElementById('stat-modal-chars');

    if (modalPages) modalPages.textContent = pages;
    if (modalWords) modalWords.textContent = words;
    if (modalChars) modalChars.textContent = chars;
  }

  // Automatic Multi-Page Pagination System
  checkPagination() {
    if (!this.pagesWrapper || !this.editorEl) return;

    const scrollHeight = this.editorEl.scrollHeight;
    const neededPages = Math.max(1, Math.ceil(scrollHeight / 860));
    const currentPages = this.pagesWrapper.querySelectorAll('.doc-page').length;

    if (neededPages > currentPages) {
      for (let i = currentPages + 1; i <= neededPages; i++) {
        const page = document.createElement('div');
        page.className = 'doc-page';
        page.id = `doc-page-${i}`;
        page.innerHTML = `
          <div class="page-header-zone" contenteditable="true" data-placeholder="Header text..."></div>
          <div class="page-continuation-note" style="color:var(--text-muted); font-size:11px; font-style:italic; padding-top:24px;">Continued from Page ${i-1}...</div>
          <div class="page-footer-zone">
            <span class="footer-text" contenteditable="true" data-placeholder="Footer text...">DocsPro Document</span>
            <span class="page-number-display">Page ${i}</span>
          </div>
        `;
        this.pagesWrapper.appendChild(page);
      }
    } else if (neededPages < currentPages && currentPages > 1) {
      for (let i = currentPages; i > neededPages; i--) {
        const pageToRemove = document.getElementById(`doc-page-${i}`);
        if (pageToRemove) pageToRemove.remove();
      }
    }
  }

  updateOutline() {
    const outlineList = document.getElementById('outline-list');
    if (!outlineList) return;

    const headings = this.editorEl.querySelectorAll('h1, h2, h3, h4, h5');
    if (headings.length === 0) {
      outlineList.innerHTML = '<li class="empty-outline">Headings you add to the document will appear here.</li>';
      return;
    }

    outlineList.innerHTML = '';
    headings.forEach((heading) => {
      const text = heading.innerText.trim();
      if (!text) return;

      const li = document.createElement('li');
      const tag = heading.tagName.toLowerCase();
      li.className = `outline-item ${tag}`;
      li.textContent = text;
      
      li.addEventListener('click', () => {
        heading.scrollIntoView({ behavior: 'smooth', block: 'center' });
      });

      outlineList.appendChild(li);
    });
  }

  activateFormatPainter() {
    showToast('Format painter active - select text');
  }
}
