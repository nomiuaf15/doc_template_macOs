/* ==========================================================================
   Interactive Ruler Module
   ========================================================================== */

import { showToast } from './toast.js';

export class InteractiveRuler {
  constructor() {
    this.rulerTicks = document.getElementById('ruler-ticks');
    this.markerFirst = document.getElementById('marker-first-indent');
    this.markerLeft = document.getElementById('marker-left-indent');
    this.markerRight = document.getElementById('marker-right-indent');
    this.editorEl = document.getElementById('editor');

    this.firstIndentPx = 96; // 1 inch
    this.leftIndentPx = 96;  // 1 inch
    this.rightIndentPx = 96; // 1 inch from right

    this.initRuler();
    this.initDraggableMarkers();
  }

  initRuler() {
    if (!this.rulerTicks) return;

    this.rulerTicks.innerHTML = '';
    const totalInches = 8.5; // Standard Letter page width in inches
    const dpi = 96; // 96px per inch
    const widthPx = totalInches * dpi; // 816px

    // Generate tick marks every 1/8 inch
    for (let i = 0; i <= totalInches * 8; i++) {
      const posPx = (i / 8) * dpi;
      const tick = document.createElement('div');
      
      const isInch = i % 8 === 0;
      const isHalf = i % 4 === 0;

      tick.className = `ruler-tick ${isInch ? 'major' : isHalf ? 'half' : 'minor'}`;
      tick.style.left = `${posPx}px`;

      if (isInch && i > 0 && i < totalInches * 8) {
        const numLabel = document.createElement('span');
        numLabel.className = 'ruler-num';
        numLabel.textContent = `${i / 8}`;
        numLabel.style.left = `${posPx}px`;
        this.rulerTicks.appendChild(numLabel);
      }

      this.rulerTicks.appendChild(tick);
    }
  }

  initDraggableMarkers() {
    this.makeDraggable(this.markerFirst, (newX) => {
      this.firstIndentPx = newX;
      this.updateEditorIndents();
    });

    this.makeDraggable(this.markerLeft, (newX) => {
      this.leftIndentPx = newX;
      this.updateEditorIndents();
    });

    this.makeDraggable(this.markerRight, (newX) => {
      this.rightIndentPx = 816 - newX;
      this.updateEditorIndents();
    });
  }

  makeDraggable(marker, onDrag) {
    if (!marker) return;

    let isDragging = false;

    marker.addEventListener('mousedown', (e) => {
      isDragging = true;
      e.preventDefault();
      document.body.style.cursor = 'ew-resize';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return;

      const rulerRect = this.rulerTicks.getBoundingClientRect();
      let mouseX = e.clientX - rulerRect.left;

      // Clamp mouse position within ruler width
      mouseX = Math.max(0, Math.min(816, mouseX));
      marker.style.left = `${mouseX}px`;

      onDrag(mouseX);
    });

    document.addEventListener('mouseup', () => {
      if (isDragging) {
        isDragging = false;
        document.body.style.cursor = 'default';
        showToast('Margin indents updated');
      }
    });
  }

  updateEditorIndents() {
    if (!this.editorEl) return;
    this.editorEl.style.paddingLeft = `${Math.max(0, this.leftIndentPx - 96)}px`;
    this.editorEl.style.paddingRight = `${Math.max(0, this.rightIndentPx - 96)}px`;
    this.editorEl.style.textIndent = `${this.firstIndentPx - this.leftIndentPx}px`;
  }
}
