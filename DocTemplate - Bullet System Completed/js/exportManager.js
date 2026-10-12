/* ==========================================================================
   Multi-Format Export & Download Manager Module
   ========================================================================== */

import { showToast } from './toast.js';

export class ExportManager {
  constructor() {
    this.editorEl = document.getElementById('editor');
    this.titleInput = document.getElementById('doc-title-input');

    this.initListeners();
  }

  initListeners() {
    document.getElementById('export-pdf')?.addEventListener('click', () => this.exportPDF());
    document.getElementById('export-docx')?.addEventListener('click', () => this.exportDocx());
    document.getElementById('export-txt')?.addEventListener('click', () => this.exportTxt());
    document.getElementById('export-html')?.addEventListener('click', () => this.exportHtml());
    document.getElementById('export-md')?.addEventListener('click', () => this.exportMarkdown());
  }

  getFilename(extension) {
    const title = this.titleInput?.value.trim() || 'Untitled_document';
    const sanitized = title.replace(/[^a-zA-Z0-9_-]/g, '_');
    return `${sanitized}.${extension}`;
  }

  downloadBlob(content, mimeType, extension) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = this.getFilename(extension);
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast(`Downloaded ${this.getFilename(extension)}`);
  }

  exportPDF() {
    showToast('Preparing PDF print layout...');
    window.print();
  }

  exportDocx() {
    const title = this.titleInput?.value || 'Document';
    const htmlContent = this.editorEl?.innerHTML || '';

    // Wrap in Microsoft Word HTML format
    const docxTemplate = `
      <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
      <head><meta charset='utf-8'><title>${title}</title>
      <style>
        body { font-family: Arial, sans-serif; font-size: 11pt; line-height: 1.5; }
        h1 { font-size: 24pt; color: #1a73e8; }
        h2 { font-size: 18pt; }
        table { border-collapse: collapse; width: 100%; }
        td, th { border: 1px solid #ccc; padding: 6px; }
      </style>
      </head>
      <body>${htmlContent}</body>
      </html>
    `;

    this.downloadBlob(docxTemplate, 'application/vnd.ms-word', 'docx');
  }

  exportTxt() {
    const text = this.editorEl?.innerText || '';
    this.downloadBlob(text, 'text/plain', 'txt');
  }

  exportHtml() {
    const title = this.titleInput?.value || 'Document';
    const body = this.editorEl?.innerHTML || '';
    const fullHtml = `<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>${title}</title>\n<style>body{font-family:Arial,sans-serif;margin:40px;line-height:1.6;}</style>\n</head>\n<body>\n${body}\n</body>\n</html>`;
    this.downloadBlob(fullHtml, 'text/html', 'html');
  }

  exportMarkdown() {
    const html = this.editorEl?.innerHTML || '';
    let md = html
      .replace(/<h1>(.*?)<\/h1>/gi, '# $1\n\n')
      .replace(/<h2>(.*?)<\/h2>/gi, '## $1\n\n')
      .replace(/<h3>(.*?)<\/h3>/gi, '### $1\n\n')
      .replace(/<strong>(.*?)<\/strong>/gi, '**$1**')
      .replace(/<b>(.*?)<\/b>/gi, '**$1**')
      .replace(/<em>(.*?)<\/em>/gi, '*$1*')
      .replace(/<i>(.*?)<\/i>/gi, '*$1*')
      .replace(/<p>(.*?)<\/p>/gi, '$1\n\n')
      .replace(/<ul>/gi, '')
      .replace(/<\/ul>/gi, '\n')
      .replace(/<li>(.*?)<\/li>/gi, '- $1\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '');

    this.downloadBlob(md, 'text/markdown', 'md');
  }
}
