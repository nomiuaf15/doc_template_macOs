/* ==========================================================================
   Document & Storage Manager Module
   ========================================================================== */

import { showToast } from './toast.js';

export class DocumentManager {
  constructor(editorEngine) {
    this.editor = editorEngine;
    this.editorEl = document.getElementById('editor');
    this.titleInput = document.getElementById('doc-title-input');
    this.summaryInput = document.getElementById('doc-summary-input');
    this.saveStatus = document.getElementById('save-status');
    this.starBtn = document.getElementById('btn-star-doc');

    this.currentDocId = 'doc_' + Date.now();
    this.docs = this.loadAllDocs();

    this.initCurrentDocument();
    this.initAutosave();
    this.initLibrary();
    this.initTemplates();
  }

  loadAllDocs() {
    try {
      const stored = localStorage.getItem('docspro_documents');
      if (stored) return JSON.parse(stored);
    } catch (e) {
      console.error(e);
    }
    return {};
  }

  saveAllDocs() {
    try {
      localStorage.setItem('docspro_documents', JSON.stringify(this.docs));
    } catch (e) {
      console.error(e);
    }
  }

  initCurrentDocument() {
    // If no document saved yet, save default initial doc
    const keys = Object.keys(this.docs);
    if (keys.length > 0) {
      this.loadDocument(keys[0]);
    } else {
      this.saveCurrentDocState();
    }

    // Title input change listener
    this.titleInput?.addEventListener('input', () => {
      this.triggerAutosave();
    });

    // Summary input listener
    this.summaryInput?.addEventListener('input', () => {
      this.triggerAutosave();
    });

    // Star button toggle
    this.starBtn?.addEventListener('click', () => {
      this.starBtn.classList.toggle('starred');
      const isStarred = this.starBtn.classList.contains('starred');
      showToast(isStarred ? 'Starred document' : 'Removed star from document');
      this.triggerAutosave();
    });
  }

  initAutosave() {
    if (!this.editorEl) return;

    this.editorEl.addEventListener('input', () => {
      this.triggerAutosave();
    });
  }

  triggerAutosave() {
    if (this.saveStatus) {
      this.saveStatus.innerHTML = `
        <span class="material-symbols-outlined status-icon" style="color:var(--google-yellow);">cloud_upload</span>
        <span class="status-text">Saving...</span>
      `;
    }

    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => {
      this.saveCurrentDocState();
      if (this.saveStatus) {
        this.saveStatus.innerHTML = `
          <span class="material-symbols-outlined status-icon">cloud_done</span>
          <span class="status-text">Saved to Drive</span>
        `;
      }
    }, 800);
  }

  saveCurrentDocState() {
    const title = this.titleInput?.value || 'Untitled document';
    const content = this.editorEl?.innerHTML || '';
    const summary = this.summaryInput?.value || '';
    const isStarred = this.starBtn?.classList.contains('starred') || false;

    this.docs[this.currentDocId] = {
      id: this.currentDocId,
      title: title,
      content: content,
      summary: summary,
      isStarred: isStarred,
      updatedAt: new Date().toISOString()
    };

    this.saveAllDocs();
  }

  loadDocument(id) {
    const doc = this.docs[id];
    if (!doc) return;

    this.currentDocId = doc.id;
    if (this.titleInput) this.titleInput.value = doc.title;
    if (this.editorEl) this.editorEl.innerHTML = doc.content;
    if (this.summaryInput) this.summaryInput.value = doc.summary || '';
    
    if (this.starBtn) {
      if (doc.isStarred) this.starBtn.classList.add('starred');
      else this.starBtn.classList.remove('starred');
    }

    this.editor.updateStats();
    this.editor.updateOutline();
    showToast(`Loaded "${doc.title}"`);
  }

  createNewDoc(title = 'Untitled document', content = '<h1>Untitled document</h1><p>Start typing here...</p>') {
    this.currentDocId = 'doc_' + Date.now();
    if (this.titleInput) this.titleInput.value = title;
    if (this.editorEl) this.editorEl.innerHTML = content;
    if (this.summaryInput) this.summaryInput.value = '';
    if (this.starBtn) this.starBtn.classList.remove('starred');

    this.saveCurrentDocState();
    this.editor.updateStats();
    this.editor.updateOutline();
    showToast(`Created new document "${title}"`);
  }

  duplicateCurrentDoc() {
    const currentTitle = this.titleInput?.value || 'Document';
    const copyTitle = `Copy of ${currentTitle}`;
    const content = this.editorEl?.innerHTML || '';

    this.createNewDoc(copyTitle, content);
  }

  initLibrary() {
    const libraryModal = document.getElementById('modal-docs-library');
    const libraryGrid = document.getElementById('docs-library-grid');
    const newDocBtn = document.getElementById('btn-new-doc-lib');

    document.getElementById('btn-drive-home')?.addEventListener('click', () => {
      this.renderLibraryGrid();
      libraryModal?.classList.add('active');
    });

    newDocBtn?.addEventListener('click', () => {
      this.createNewDoc();
      libraryModal?.classList.remove('active');
    });
  }

  renderLibraryGrid() {
    const grid = document.getElementById('docs-library-grid');
    if (!grid) return;

    const docList = Object.values(this.docs);
    if (docList.length === 0) {
      grid.innerHTML = '<p style="grid-column:1/-1; color:var(--text-muted);">No documents saved yet.</p>';
      return;
    }

    grid.innerHTML = '';
    docList.forEach((doc) => {
      const card = document.createElement('div');
      card.className = 'doc-card';
      card.innerHTML = `
        <div class="template-preview">
          <div class="tp-line title">${doc.title}</div>
          <div class="tp-block"></div>
        </div>
        <h4>${doc.title}</h4>
        <p style="font-size:11px; color:var(--text-muted);">Updated ${new Date(doc.updatedAt).toLocaleDateString()}</p>
      `;

      card.addEventListener('click', () => {
        this.loadDocument(doc.id);
        document.getElementById('modal-docs-library')?.classList.remove('active');
      });

      grid.appendChild(card);
    });
  }

  initTemplates() {
    const templatesModal = document.getElementById('modal-templates');
    const templateCards = document.querySelectorAll('.template-card');

    templateCards.forEach((card) => {
      card.addEventListener('click', () => {
        const type = card.getAttribute('data-template');
        this.loadTemplate(type);
        templatesModal?.classList.remove('active');
      });
    });
  }

  loadTemplate(type) {
    let title = 'Document Template';
    let content = '';

    if (type === 'resume') {
      title = 'Modern Resume - Alex Morgan';
      content = `
        <h1>Alex Morgan</h1>
        <p style="color:var(--text-muted); font-size:12pt; margin-bottom:20px;">Senior Full Stack Engineer &nbsp;•&nbsp; alex@example.com &nbsp;•&nbsp; (555) 019-2834</p>
        
        <h2>Executive Summary</h2>
        <p>Experienced Senior Software Engineer with over 8 years of expertise in building high-scale web platforms, distributed systems, and intuitive user interfaces.</p>

        <h2>Work Experience</h2>
        <h3>Lead Frontend Architect — TechCorp Inc. (2021 – Present)</h3>
        <ul>
          <li>Engineered real-time collaborative document platform serving over 2M active users daily.</li>
          <li>Optimized DOM rendering pipeline resulting in a 45% reduction in main-thread frame latency.</li>
        </ul>

        <h3>Senior Software Engineer — CloudScale Labs (2018 – 2021)</h3>
        <ul>
          <li>Developed responsive web applications using React, TypeScript, and WebSockets.</li>
        </ul>

        <h2>Education</h2>
        <p><strong>B.S. in Computer Science</strong> — Stanford University (2014 – 2018)</p>
      `;
    } else if (type === 'proposal') {
      title = 'Project Proposal - Enterprise Cloud Migration';
      content = `
        <h1>Project Proposal: Enterprise Cloud Migration</h1>
        <p style="color:var(--text-muted); margin-bottom:24px;">Prepared by Cloud Services Team &nbsp;•&nbsp; Date: October 2026</p>
        
        <h2>1. Executive Overview</h2>
        <p>This proposal outlines the strategy, architecture, and deployment timeline for migrating on-premise infrastructure to a cloud-native serverless ecosystem.</p>

        <h2>2. Objectives & Scope</h2>
        <ul>
          <li>Achieve 99.99% system availability and high fault tolerance.</li>
          <li>Reduce operational infrastructure expenses by 30% over 12 months.</li>
        </ul>

        <h2>3. Estimated Budget</h2>
        <table>
          <tr><th>Phase</th><th>Estimated Hours</th><th>Cost</th></tr>
          <tr><td>Phase 1: Architecture & Audit</td><td>80 hrs</td><td>$12,000</td></tr>
          <tr><td>Phase 2: Migration & Testing</td><td>160 hrs</td><td>$24,000</td></tr>
        </table>
      `;
    } else if (type === 'meeting') {
      title = 'Weekly Product Sync - Meeting Notes';
      content = `
        <h1>Weekly Product Sync</h1>
        <p style="color:var(--text-muted); margin-bottom:20px;"><strong>Date:</strong> October 7, 2026 &nbsp;|&nbsp; <strong>Attendees:</strong> Sarah, Alex, Liam, Maya</p>

        <h2>Agenda</h2>
        <ol>
          <li>Q4 Roadmap Review</li>
          <li>UI Redesign & Material 3 Specs</li>
          <li>Open QA Blockers</li>
        </ol>

        <h2>Key Discussion Points</h2>
        <p>Sarah presented the revised editor mockups. The team agreed on prioritizing rich comment threads and suggest mode prior to launch.</p>

        <h2>Action Items</h2>
        <ul>
          <li><input type="checkbox" checked> Alex: Finalize export PDF formatting</li>
          <li><input type="checkbox"> Maya: Conduct user test on drawing modal</li>
        </ul>
      `;
    } else if (type === 'essay') {
      title = 'Academic Research Paper - Artificial Intelligence';
      content = `
        <h1 style="text-align:center;">The Evolution of Neural Collaborative Filtering</h1>
        <p style="text-align:center; color:var(--text-muted); margin-bottom:32px;">By Jane Doe &nbsp;•&nbsp; Department of Computer Science</p>

        <h2>Abstract</h2>
        <p>Recent advances in deep neural architectures have transformed natural language processing and collaborative content editing frameworks...</p>

        <h2>1. Introduction</h2>
        <p>In classical text processing, static data models often failed to capture real-time document state changes. Modern browser APIs enable latency-free DOM mutations...</p>
      `;
    }

    this.createNewDoc(title, content);
  }
}
