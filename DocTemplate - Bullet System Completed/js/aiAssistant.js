/* ==========================================================================
   Gemini AI Assistant Module ("Help me write")
   ========================================================================== */

import { showToast } from './toast.js';

export class AIAssistant {
  constructor(editorEngine) {
    this.editor = editorEngine;
    this.editorEl = document.getElementById('editor');
    this.modal = document.getElementById('modal-ai-writer');
    this.promptInput = document.getElementById('ai-prompt-input');
    this.outputContainer = document.getElementById('ai-output-container');
    this.outputBox = document.getElementById('ai-output-box');
    this.insertBtn = document.getElementById('btn-ai-insert');

    this.initListeners();
  }

  initListeners() {
    // Open modal triggers
    document.getElementById('btn-ai-spark')?.addEventListener('click', () => this.openModal());
    document.getElementById('companion-ai')?.addEventListener('click', () => this.openModal());

    // Generate button
    document.getElementById('btn-ai-generate')?.addEventListener('click', () => this.generateContent());

    // Quick prompt chips
    document.querySelectorAll('.chip-btn').forEach((chip) => {
      chip.addEventListener('click', () => {
        const type = chip.getAttribute('data-ai');
        this.applyQuickPrompt(type);
      });
    });

    // Insert button
    this.insertBtn?.addEventListener('click', () => {
      const content = this.outputBox?.innerHTML;
      if (content) {
        this.editor.execute('insertHTML', content);
        this.modal?.classList.remove('active');
        showToast('AI content inserted into document');
      }
    });
  }

  openModal() {
    this.modal?.classList.add('active');
    this.promptInput?.focus();
  }

  applyQuickPrompt(type) {
    if (!this.promptInput) return;

    if (type === 'cover-letter') {
      this.promptInput.value = 'Draft a formal cover letter for a Senior Software Engineer application at Google.';
    } else if (type === 'executive-summary') {
      this.promptInput.value = 'Write a concise 3-paragraph executive summary for a project launch proposal.';
    } else if (type === 'improve-tone') {
      this.promptInput.value = 'Rewrite the current document content to sound polished, persuasive, and executive.';
    } else if (type === 'fix-grammar') {
      this.promptInput.value = 'Proofread and correct all grammar, spelling, and punctuation errors.';
    }

    this.generateContent();
  }

  generateContent() {
    const prompt = this.promptInput?.value.trim();
    if (!prompt) {
      showToast('Please enter a prompt or select a quick option');
      return;
    }

    if (this.outputContainer) this.outputContainer.style.display = 'block';
    if (this.outputBox) this.outputBox.innerHTML = '<em>Gemini is generating response...</em>';

    // Simulate smart AI response generation
    setTimeout(() => {
      let draft = '';

      if (prompt.toLowerCase().includes('cover letter')) {
        draft = `
          <p><strong>Dear Hiring Manager,</strong></p>
          <p>I am writing to express my enthusiastic interest in the Senior Software Engineer position. With over eight years of experience building mission-critical distributed systems and intuitive Web applications, I am eager to contribute to your engineering organization.</p>
          <p>In my previous role, I spearheaded the redesign of a high-concurrency editor engine that increased productivity for millions of daily active users while lowering memory footprint by 40%.</p>
          <p>Thank you for your time and consideration. I look forward to discussing how my technical skills align with your goals.</p>
          <p>Sincerely,<br><strong>Candidate Name</strong></p>
        `;
      } else if (prompt.toLowerCase().includes('summary') || prompt.toLowerCase().includes('executive')) {
        draft = `
          <h3>Executive Summary</h3>
          <p>This initiative establishes a modern cloud infrastructure designed to support rapid scaling, enterprise security compliance, and latency-free document collaboration across cross-functional teams.</p>
          <p>Key outcomes include a 35% reduction in infrastructure overhead and complete feature parity with legacy desktop document editors.</p>
        `;
      } else {
        draft = `
          <p><strong>AI Drafted Content:</strong></p>
          <p>Based on your prompt "<em>${prompt}</em>", here is a polished draft:</p>
          <p>Effective collaboration relies on intuitive tools, clear structural formatting, and seamless real-time iteration across multi-user environments.</p>
        `;
      }

      if (this.outputBox) this.outputBox.innerHTML = draft;
      if (this.insertBtn) this.insertBtn.style.display = 'inline-flex';
    }, 900);
  }
}
