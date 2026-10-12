/* ==========================================================================
   Drawing Canvas Modal Module
   ========================================================================== */

import { showToast } from './toast.js';

export class DrawingModalManager {
  constructor(editorEngine) {
    this.editor = editorEngine;
    this.modal = document.getElementById('modal-drawing');
    this.canvas = document.getElementById('drawing-canvas');
    this.ctx = this.canvas ? this.canvas.getContext('2d') : null;

    this.currentTool = 'pencil'; // 'pencil' | 'line' | 'rect' | 'circle'
    this.currentColor = '#1a73e8';
    this.currentWidth = 4;
    this.isDrawing = false;
    this.startX = 0;
    this.startY = 0;
    this.snapshot = null;

    this.initListeners();
  }

  initListeners() {
    document.getElementById('insert-drawing-btn')?.addEventListener('click', () => {
      this.openModal();
    });

    document.getElementById('btn-insert-drawing')?.addEventListener('click', () => {
      this.insertDrawingToDoc();
    });

    // Tool switchers
    document.getElementById('draw-tool-pencil')?.addEventListener('click', (e) => this.setTool('pencil', e.currentTarget));
    document.getElementById('draw-tool-line')?.addEventListener('click', (e) => this.setTool('line', e.currentTarget));
    document.getElementById('draw-tool-rect')?.addEventListener('click', (e) => this.setTool('rect', e.currentTarget));
    document.getElementById('draw-tool-circle')?.addEventListener('click', (e) => this.setTool('circle', e.currentTarget));

    document.getElementById('draw-color-picker')?.addEventListener('input', (e) => {
      this.currentColor = e.target.value;
    });

    document.getElementById('draw-line-width')?.addEventListener('change', (e) => {
      this.currentWidth = parseInt(e.target.value);
    });

    document.getElementById('draw-clear-btn')?.addEventListener('click', () => this.clearCanvas());

    if (!this.canvas) return;

    this.canvas.addEventListener('mousedown', (e) => this.startDraw(e));
    this.canvas.addEventListener('mousemove', (e) => this.drawing(e));
    this.canvas.addEventListener('mouseup', () => this.stopDraw());
  }

  openModal() {
    this.clearCanvas();
    this.modal?.classList.add('active');
  }

  setTool(tool, btn) {
    this.currentTool = tool;
    document.querySelectorAll('.drawing-tools-bar .tb-btn').forEach(b => b.classList.remove('active'));
    btn?.classList.add('active');
  }

  clearCanvas() {
    if (!this.ctx || !this.canvas) return;
    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
  }

  startDraw(e) {
    this.isDrawing = true;
    const rect = this.canvas.getBoundingClientRect();
    this.startX = e.clientX - rect.left;
    this.startY = e.clientY - rect.top;

    this.ctx.beginPath();
    this.ctx.lineWidth = this.currentWidth;
    this.ctx.strokeStyle = this.currentColor;
    this.ctx.fillStyle = this.currentColor;
    this.ctx.lineCap = 'round';

    this.snapshot = this.ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
  }

  drawing(e) {
    if (!this.isDrawing) return;
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    if (this.currentTool === 'pencil') {
      this.ctx.lineTo(mouseX, mouseY);
      this.ctx.stroke();
    } else {
      this.ctx.putImageData(this.snapshot, 0, 0);
      this.ctx.beginPath();
      if (this.currentTool === 'line') {
        this.ctx.moveTo(this.startX, this.startY);
        this.ctx.lineTo(mouseX, mouseY);
        this.ctx.stroke();
      } else if (this.currentTool === 'rect') {
        this.ctx.strokeRect(this.startX, this.startY, mouseX - this.startX, mouseY - this.startY);
      } else if (this.currentTool === 'circle') {
        const radius = Math.sqrt(Math.pow(mouseX - this.startX, 2) + Math.pow(mouseY - this.startY, 2));
        this.ctx.arc(this.startX, this.startY, radius, 0, 2 * Math.PI);
        this.ctx.stroke();
      }
    }
  }

  stopDraw() {
    this.isDrawing = false;
  }

  insertDrawingToDoc() {
    if (!this.canvas) return;
    const dataUrl = this.canvas.toDataURL('image/png');
    this.editor.execute('insertImage', dataUrl);
    this.modal?.classList.remove('active');
    showToast('Drawing inserted');
  }
}
