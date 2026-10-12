/* ==========================================================================
   Find & Replace Floating Dialog Module
   ========================================================================== */

import { showToast } from './toast.js';

export class FindReplaceManager {
  constructor() {
    this.dialog = document.getElementById('dialog-find-replace');
    this.findInput = document.getElementById('find-input');
    this.replaceInput = document.getElementById('replace-input');
    this.matchCountSpan = document.getElementById('find-match-count');
    this.matchCaseCheck = document.getElementById('find-match-case');
    this.editorEl = document.getElementById('editor');

    this.currentIndex = 0;
    this.matches = [];

    this.initListeners();
  }

  initListeners() {
    document.getElementById('btn-close-find')?.addEventListener('click', () => {
      this.closeDialog();
    });

    this.findInput?.addEventListener('input', () => this.performFind());
    this.matchCaseCheck?.addEventListener('change', () => this.performFind());

    document.getElementById('find-next')?.addEventListener('click', () => this.navigateMatch(1));
    document.getElementById('find-prev')?.addEventListener('click', () => this.navigateMatch(-1));

    document.getElementById('btn-replace')?.addEventListener('click', () => this.replaceCurrent());
    document.getElementById('btn-replace-all')?.addEventListener('click', () => this.replaceAll());
  }

  closeDialog() {
    if (this.dialog) this.dialog.style.display = 'none';
    this.clearHighlights();
  }

  performFind() {
    this.clearHighlights();
    const query = this.findInput?.value || '';
    if (!query) {
      if (this.matchCountSpan) this.matchCountSpan.textContent = '0 of 0';
      return;
    }

    const matchCase = this.matchCaseCheck?.checked || false;
    const text = this.editorEl?.innerText || '';
    const regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), matchCase ? 'g' : 'gi');

    let match;
    this.matches = [];
    while ((match = regex.exec(text)) !== null) {
      this.matches.push(match.index);
    }

    if (this.matchCountSpan) {
      this.matchCountSpan.textContent = `${this.matches.length > 0 ? 1 : 0} of ${this.matches.length}`;
    }
    this.currentIndex = 0;
  }

  navigateMatch(direction) {
    if (this.matches.length === 0) return;

    this.currentIndex = (this.currentIndex + direction + this.matches.length) % this.matches.length;
    if (this.matchCountSpan) {
      this.matchCountSpan.textContent = `${this.currentIndex + 1} of ${this.matches.length}`;
    }
  }

  replaceCurrent() {
    const query = this.findInput?.value || '';
    const replacement = this.replaceInput?.value || '';
    if (!query || !this.editorEl) return;

    const matchCase = this.matchCaseCheck?.checked || false;
    const regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), matchCase ? '' : 'i');

    if (regex.test(this.editorEl.innerHTML)) {
      this.editorEl.innerHTML = this.editorEl.innerHTML.replace(regex, replacement);
      showToast('Replaced 1 occurrence');
      this.performFind();
    }
  }

  replaceAll() {
    const query = this.findInput?.value || '';
    const replacement = this.replaceInput?.value || '';
    if (!query || !this.editorEl) return;

    const matchCase = this.matchCaseCheck?.checked || false;
    const regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), matchCase ? 'g' : 'gi');

    const count = (this.editorEl.innerHTML.match(regex) || []).length;
    this.editorEl.innerHTML = this.editorEl.innerHTML.replace(regex, replacement);
    showToast(`Replaced ${count} occurrences`);
    this.performFind();
  }

  clearHighlights() {
    // Clear find highlights if any
  }
}
