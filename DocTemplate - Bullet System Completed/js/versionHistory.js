/* ==========================================================================
   Version History & Snapshots Module
   ========================================================================== */

import { showToast } from './toast.js';

export class VersionHistoryManager {
  constructor(editorEngine) {
    this.editor = editorEngine;
    this.editorEl = document.getElementById('editor');
    this.rightSidebar = document.getElementById('right-sidebar');
    this.sidebarTitle = document.getElementById('right-sidebar-title');
    this.sidebarContent = document.getElementById('right-sidebar-content');

    this.history = [];
    this.createSnapshot('Initial version');

    this.initListeners();
  }

  initListeners() {
    document.getElementById('menu-version-history')?.addEventListener('click', () => this.showHistoryPanel());
    document.getElementById('companion-history')?.addEventListener('click', () => this.showHistoryPanel());
  }

  createSnapshot(name = null) {
    if (!this.editorEl) return;
    const content = this.editorEl.innerHTML;
    const snapshotName = name || `Version ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    this.history.unshift({
      id: 'ver_' + Date.now(),
      name: snapshotName,
      content: content,
      time: new Date().toLocaleString()
    });
  }

  showHistoryPanel() {
    if (!this.rightSidebar || !this.sidebarContent) return;

    if (this.sidebarTitle) this.sidebarTitle.textContent = 'Version history';
    this.rightSidebar.classList.remove('collapsed');

    this.renderHistoryList();
  }

  renderHistoryList() {
    if (this.history.length === 0) {
      this.sidebarContent.innerHTML = '<p style="padding:16px; color:var(--text-muted);">No version history available.</p>';
      return;
    }

    let html = `
      <div style="margin-bottom:12px;">
        <button class="btn btn-secondary btn-sm" id="btn-create-named-version" style="width:100%;">
          <span class="material-symbols-outlined">add</span> Name current version
        </button>
      </div>
      <div class="version-list" style="display:flex; flex-direction:column; gap:8px;">
    `;

    this.history.forEach((ver, index) => {
      html += `
        <div class="comment-card version-item" data-id="${ver.id}">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <strong style="font-size:13px; color:var(--google-blue);">${ver.name}</strong>
            ${index === 0 ? '<span style="font-size:10px; background:var(--google-blue-light); color:var(--google-blue); padding:1px 6px; border-radius:10px;">Current</span>' : ''}
          </div>
          <span style="font-size:11px; color:var(--text-muted);">${ver.time}</span>
          <div style="margin-top:8px; display:flex; gap:6px;">
            <button class="btn btn-primary btn-sm btn-restore-ver" data-id="${ver.id}">Restore</button>
          </div>
        </div>
      `;
    });

    html += `</div>`;
    this.sidebarContent.innerHTML = html;

    // Attach listeners
    document.getElementById('btn-create-named-version')?.addEventListener('click', () => {
      const name = prompt('Name this version:');
      if (name) {
        this.createSnapshot(name);
        this.renderHistoryList();
        showToast('Version named');
      }
    });

    this.sidebarContent.querySelectorAll('.btn-restore-ver').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-id');
        this.restoreVersion(id);
      });
    });
  }

  restoreVersion(id) {
    const ver = this.history.find((v) => v.id === id);
    if (!ver) return;

    if (confirm(`Restore "${ver.name}"? Unsaved changes will be replaced.`)) {
      this.editorEl.innerHTML = ver.content;
      this.editor.updateStats();
      this.editor.updateOutline();
      showToast(`Restored to "${ver.name}"`);
    }
  }
}
