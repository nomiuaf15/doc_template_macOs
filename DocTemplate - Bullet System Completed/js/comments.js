/* ==========================================================================
   Comments & Threading Module
   ========================================================================== */

import { showToast } from './toast.js';

export class CommentsManager {
  constructor() {
    this.editorEl = document.getElementById('editor');
    this.commentsContainer = document.getElementById('comments-container');
    this.rightSidebar = document.getElementById('right-sidebar');
    this.badge = document.getElementById('comments-count-badge');

    this.comments = [];

    this.initListeners();
  }

  initListeners() {
    // Add comment button triggers
    document.getElementById('tb-add-comment')?.addEventListener('click', () => this.createCommentFromSelection());
    document.getElementById('insert-comment-btn')?.addEventListener('click', () => this.createCommentFromSelection());
    document.getElementById('btn-toggle-comments')?.addEventListener('click', () => this.toggleSidebar());
    document.getElementById('companion-comments')?.addEventListener('click', () => this.toggleSidebar());
    document.getElementById('btn-close-right-sidebar')?.addEventListener('click', () => {
      this.rightSidebar?.classList.add('collapsed');
    });

    // Keyboard shortcut Ctrl+Alt+M for Add Comment
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'm') {
        e.preventDefault();
        this.createCommentFromSelection();
      }
    });

    // Click on highlighted comment span in editor scrolls right sidebar card
    this.editorEl?.addEventListener('click', (e) => {
      const commentSpan = e.target.closest('.comment-highlight');
      if (commentSpan) {
        const id = commentSpan.getAttribute('data-comment-id');
        this.highlightCommentCard(id);
      }
    });
  }

  toggleSidebar() {
    if (this.rightSidebar) {
      this.rightSidebar.classList.toggle('collapsed');
    }
  }

  createCommentFromSelection() {
    const selection = window.getSelection();
    if (!selection.rangeCount || selection.isCollapsed) {
      showToast('Select text first to add a comment');
      return;
    }

    const text = prompt('Enter your comment:');
    if (!text || !text.trim()) return;

    const range = selection.getRangeAt(0);
    const selectedText = range.toString();
    const commentId = 'comment_' + Date.now();

    // Wrap selection in comment span
    const span = document.createElement('span');
    span.className = 'comment-highlight';
    span.setAttribute('data-comment-id', commentId);
    range.surroundContents(span);

    const commentData = {
      id: commentId,
      quotedText: selectedText,
      author: 'You',
      avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix&backgroundColor=b6e3f4',
      text: text,
      time: 'Just now',
      replies: [],
      resolved: false
    };

    this.comments.push(commentData);
    this.renderComments();
    this.rightSidebar?.classList.remove('collapsed');
    showToast('Comment added');
  }

  renderComments() {
    if (!this.commentsContainer) return;

    const activeComments = this.comments.filter((c) => !c.resolved);

    // Update badge count
    if (this.badge) {
      if (activeComments.length > 0) {
        this.badge.textContent = activeComments.length;
        this.badge.style.display = 'inline-block';
      } else {
        this.badge.style.display = 'none';
      }
    }

    if (activeComments.length === 0) {
      this.commentsContainer.innerHTML = `
        <div class="empty-comments-state">
          <span class="material-symbols-outlined">add_comment</span>
          <p>No comments yet</p>
          <span>Highlight text and press <strong>Ctrl+Alt+M</strong> or click the comment button to add a comment.</span>
        </div>
      `;
      return;
    }

    this.commentsContainer.innerHTML = '';

    activeComments.forEach((c) => {
      const card = document.createElement('div');
      card.className = 'comment-card';
      card.id = `card_${c.id}`;

      let repliesHtml = '';
      if (c.replies && c.replies.length > 0) {
        repliesHtml = c.replies.map(r => `
          <div style="margin-top:8px; padding-left:12px; border-left:2px solid var(--border-light); font-size:12px;">
            <strong>${r.author}:</strong> ${r.text}
          </div>
        `).join('');
      }

      card.innerHTML = `
        <div class="comment-header">
          <img class="comment-author-avatar" src="${c.avatar}" alt="Avatar">
          <span class="comment-author-name">${c.author}</span>
          <span class="comment-time">${c.time}</span>
        </div>
        <div class="comment-quoted-text">"${c.quotedText}"</div>
        <div class="comment-body-text">${c.text}</div>
        ${repliesHtml}
        <div class="comment-actions">
          <button class="btn btn-secondary btn-sm btn-reply" data-id="${c.id}">Reply</button>
          <button class="btn btn-primary btn-sm btn-resolve" data-id="${c.id}">Resolve</button>
        </div>
      `;

      // Reply listener
      card.querySelector('.btn-reply')?.addEventListener('click', () => {
        const replyText = prompt('Reply to comment:');
        if (replyText) {
          c.replies.push({ author: 'You', text: replyText });
          this.renderComments();
        }
      });

      // Resolve listener
      card.querySelector('.btn-resolve')?.addEventListener('click', () => {
        c.resolved = true;
        this.removeHighlightFromDoc(c.id);
        this.renderComments();
        showToast('Comment resolved');
      });

      this.commentsContainer.appendChild(card);
    });
  }

  highlightCommentCard(id) {
    this.rightSidebar?.classList.remove('collapsed');
    document.querySelectorAll('.comment-card').forEach((card) => card.classList.remove('active'));
    const targetCard = document.getElementById(`card_${id}`);
    if (targetCard) {
      targetCard.classList.add('active');
      targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }

  removeHighlightFromDoc(commentId) {
    const span = this.editorEl.querySelector(`span[data-comment-id="${commentId}"]`);
    if (span) {
      const parent = span.parentNode;
      while (span.firstChild) {
        parent.insertBefore(span.firstChild, span);
      }
      parent.removeChild(span);
    }
  }
}
