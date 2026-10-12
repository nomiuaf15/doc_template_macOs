/* ==========================================================================
   Toolbar & Navigation Controller
   ========================================================================== */

import { showToast } from './toast.js';

export class ToolbarController {
  constructor(editorEngine) {
    this.editor = editorEngine;
    this.initNavigation();
    this.initMenus();
    this.initToolbarControls();
  }

  initNavigation() {
    const dashView = document.getElementById('docs-dashboard-view');
    const editorView = document.getElementById('doc-editor-view');

    // Back to dashboard logo click
    document.getElementById('btn-back-to-dash')?.addEventListener('click', () => {
      if (dashView && editorView) {
        editorView.style.display = 'none';
        dashView.style.display = 'flex';
        showToast('Returned to Docs Home');
      }
    });

    document.getElementById('menu-open-docs')?.addEventListener('click', () => {
      if (dashView && editorView) {
        editorView.style.display = 'none';
        dashView.style.display = 'flex';
      }
    });
  }

  initMenus() {
    const menuItems = document.querySelectorAll('.menu-bar .menu-item');
    
    menuItems.forEach((item) => {
      item.addEventListener('click', (e) => {
        e.stopPropagation();
        const wasActive = item.classList.contains('active');
        menuItems.forEach((m) => m.classList.remove('active'));
        if (!wasActive) item.classList.add('active');
      });
    });

    document.addEventListener('click', () => {
      menuItems.forEach((m) => m.classList.remove('active'));
    });

    // Formatting Actions
    document.getElementById('fmt-bold')?.addEventListener('click', () => this.editor.execute('bold'));
    document.getElementById('fmt-italic')?.addEventListener('click', () => this.editor.execute('italic'));
    document.getElementById('fmt-underline')?.addEventListener('click', () => this.editor.execute('underline'));
    document.getElementById('fmt-strikethrough')?.addEventListener('click', () => this.editor.execute('strikeThrough'));
    document.getElementById('fmt-clear')?.addEventListener('click', () => this.editor.execute('removeFormat'));

    // Edit Actions
    document.getElementById('edit-undo')?.addEventListener('click', () => this.editor.execute('undo'));
    document.getElementById('edit-redo')?.addEventListener('click', () => this.editor.execute('redo'));
    document.getElementById('edit-cut')?.addEventListener('click', () => this.editor.execute('cut'));
    document.getElementById('edit-copy')?.addEventListener('click', () => this.editor.execute('copy'));
    document.getElementById('edit-select-all')?.addEventListener('click', () => this.editor.execute('selectAll'));
    document.getElementById('edit-find-replace')?.addEventListener('click', () => {
      document.getElementById('dialog-find-replace').style.display = 'block';
    });

    // Modes
    document.getElementById('mode-editing')?.addEventListener('click', () => this.editor.setMode('editing'));
    document.getElementById('mode-suggesting')?.addEventListener('click', () => this.editor.setMode('suggesting'));
    document.getElementById('mode-viewing')?.addEventListener('click', () => this.editor.setMode('viewing'));

    document.getElementById('toggle-ruler-menu')?.addEventListener('click', () => {
      const ruler = document.getElementById('ruler-container');
      if (ruler) ruler.style.display = ruler.style.display === 'none' ? 'block' : 'none';
    });

    document.getElementById('toggle-outline-menu')?.addEventListener('click', () => {
      document.getElementById('left-sidebar')?.classList.toggle('collapsed');
    });

    document.getElementById('toggle-dark-mode')?.addEventListener('click', () => {
      document.body.classList.toggle('theme-dark');
    });
  }

  initToolbarControls() {
    // Formatting Buttons
    document.getElementById('tb-bold')?.addEventListener('click', () => this.editor.execute('bold'));
    document.getElementById('tb-italic')?.addEventListener('click', () => this.editor.execute('italic'));
    document.getElementById('tb-underline')?.addEventListener('click', () => this.editor.execute('underline'));
    document.getElementById('tb-undo')?.addEventListener('click', () => this.editor.execute('undo'));
    document.getElementById('tb-redo')?.addEventListener('click', () => this.editor.execute('redo'));
    document.getElementById('tb-print')?.addEventListener('click', () => window.print());

    // Font family & Font size dropdowns
    document.getElementById('tb-font-select')?.addEventListener('change', (e) => {
      this.editor.setFontFamily(e.target.value);
    });

    document.getElementById('tb-font-size-select')?.addEventListener('change', (e) => {
      this.editor.setFontSize(parseInt(e.target.value));
    });

    // Paragraph Style select
    document.getElementById('tb-style-select')?.addEventListener('change', (e) => {
      this.editor.setBlockStyle(e.target.value);
    });

    // Zoom level dropdown
    document.getElementById('tb-zoom-select')?.addEventListener('change', (e) => {
      const zoom = parseInt(e.target.value) / 100;
      const workspace = document.getElementById('document-workspace');
      if (workspace) {
        workspace.style.transform = `scale(${zoom})`;
        workspace.style.transformOrigin = 'top center';
      }
    });

    // Colors
    document.getElementById('tb-text-color-picker')?.addEventListener('input', (e) => {
      this.editor.setTextColor(e.target.value);
    });

    document.getElementById('tb-bg-color-picker')?.addEventListener('input', (e) => {
      this.editor.setHighlightColor(e.target.value);
    });

    // Alignments & Lists
    document.getElementById('tb-align-left')?.addEventListener('click', () => this.editor.setAlignment('left'));
    document.getElementById('tb-align-center')?.addEventListener('click', () => this.editor.setAlignment('center'));
    document.getElementById('tb-align-right')?.addEventListener('click', () => this.editor.setAlignment('right'));
    document.getElementById('tb-align-justify')?.addEventListener('click', () => this.editor.setAlignment('justify'));
    document.getElementById('tb-bullet-list')?.addEventListener('click', () => this.editor.execute('insertUnorderedList'));
    document.getElementById('tb-number-list')?.addEventListener('click', () => this.editor.execute('insertOrderedList'));
    document.getElementById('tb-indent')?.addEventListener('click', () => this.editor.execute('indent'));
    document.getElementById('tb-outdent')?.addEventListener('click', () => this.editor.execute('outdent'));
    document.getElementById('tb-clear-fmt')?.addEventListener('click', () => this.editor.execute('removeFormat'));
  }
}
