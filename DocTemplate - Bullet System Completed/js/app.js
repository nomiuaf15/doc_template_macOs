/* ==========================================================================
   DocsPro - Main Application Orchestrator
   ========================================================================== */

import { EditorEngine } from './editor.js';
import { InteractiveRuler } from './ruler.js';
import { ToolbarController } from './toolbar.js';
import { DocumentManager } from './documentManager.js';
import { CommentsManager } from './comments.js';
import { VersionHistoryManager } from './versionHistory.js';
import { ExportManager } from './exportManager.js';
import { FindReplaceManager } from './findReplace.js';
import { AIAssistant } from './aiAssistant.js';
import { DrawingModalManager } from './drawingModal.js';
import { showToast } from './toast.js';

document.addEventListener('DOMContentLoaded', () => {
  // 1. Initialize Core Components
  const editorEngine = new EditorEngine();
  const ruler = new InteractiveRuler();
  const toolbar = new ToolbarController(editorEngine);
  const docManager = new DocumentManager(editorEngine);
  const commentsManager = new CommentsManager();
  const versionHistory = new VersionHistoryManager(editorEngine);
  const exportManager = new ExportManager();
  const findReplace = new FindReplaceManager();
  const aiAssistant = new AIAssistant(editorEngine);
  const drawingModal = new DrawingModalManager(editorEngine);

  window.docManager = docManager;

  // 2. Dashboard Template Cards Handler
  const dashView = document.getElementById('docs-dashboard-view');
  const editorView = document.getElementById('doc-editor-view');

  document.querySelectorAll('.tmpl-card').forEach((card) => {
    card.addEventListener('click', () => {
      const templateType = card.getAttribute('data-template');
      if (templateType === 'blank') {
        docManager.createNewDoc('Untitled document', '<h1>Untitled document</h1><p>Start typing here...</p>');
      } else {
        docManager.loadTemplate(templateType);
      }

      if (dashView && editorView) {
        dashView.style.display = 'none';
        editorView.style.display = 'flex';
      }
    });
  });

  // 3. Close Modal Overlays on Background Click or Close Button
  document.querySelectorAll('.modal-overlay').forEach((overlay) => {
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay || e.target.classList.contains('modal-close-btn')) {
        overlay.classList.remove('active');
      }
    });
  });

  // 4. Keyboard Shortcuts
  document.addEventListener('keydown', (e) => {
    // Ctrl+P / Cmd+P Print
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'p') {
      e.preventDefault();
      window.print();
    }
    // Ctrl+Shift+C Word Count
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      document.getElementById('modal-word-count')?.classList.add('active');
    }
  });

  showToast('Welcome to Google Docs', 2500);
});
