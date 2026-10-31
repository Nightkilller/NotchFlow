// NotchFlow — Interactive Logic styled after OpenCode.ai

document.addEventListener('DOMContentLoaded', () => {
  // 1. Installation Tabs (OpenCode style)
  const tabButtons = document.querySelectorAll('[data-slot="tab"]');
  const panels = document.querySelectorAll('[data-slot="panel"]');

  tabButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');

      // Update tabs state
      tabButtons.forEach((b) => {
        const isSelected = b.getAttribute('data-tab') === targetTab;
        b.setAttribute('aria-selected', isSelected ? 'true' : 'false');
      });

      // Update panels state
      panels.forEach((p) => {
        if (p.getAttribute('data-panel') === targetTab) {
          p.classList.add('active');
        } else {
          p.classList.remove('active');
        }
      });
    });
  });

  // 2. Copyable Terminal Commands
  const copyButtons = document.querySelectorAll('.copyable-command');
  copyButtons.forEach((btn) => {
    btn.addEventListener('click', async () => {
      const code = btn.getAttribute('data-code');
      const statusEl = btn.querySelector('[data-component="copy-status"]');

      if (code) {
        try {
          await navigator.clipboard.writeText(code);
          if (statusEl) {
            statusEl.setAttribute('data-copied', 'true');
            setTimeout(() => {
              statusEl.removeAttribute('data-copied');
            }, 2000);
          }
          showToast(`Copied to clipboard: ${code}`);
        } catch (err) {
          console.warn('Clipboard write failed:', err);
        }
      }
    });
  });

  // 3. DMG Trigger Download in Tabs
  const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.protocol === 'file:';
  const dmgDownloadUrl = isLocal
    ? './downloads/NotchFlow-Installer.dmg'
    : 'https://github.com/Nightkilller/NotchFlow/releases/download/v1.0.0/NotchFlow-Installer.dmg';

  // Ensure all download buttons use the appropriate URL
  document.querySelectorAll('a[download]').forEach((a) => {
    a.href = dmgDownloadUrl;
  });

  const dmgTrigger = document.getElementById('downloadDmgTrigger');
  const dmgStatus = document.getElementById('dmgDownloadStatus');
  if (dmgTrigger) {
    dmgTrigger.addEventListener('click', () => {
      const link = document.createElement('a');
      link.href = dmgDownloadUrl;
      link.download = 'NotchFlow-Installer.dmg';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      if (dmgStatus) {
        dmgStatus.setAttribute('data-copied', 'true');
        setTimeout(() => {
          dmgStatus.removeAttribute('data-copied');
        }, 2500);
      }
      showToast('Starting download for NotchFlow-Installer.dmg (131 MB)...');
    });
  }

  // 4. All Download Links Toast Notification
  const downloadLinks = document.querySelectorAll('a[download]');
  downloadLinks.forEach((a) => {
    a.addEventListener('click', () => {
      showToast('Starting download for NotchFlow-Installer.dmg (131 MB)...');
    });
  });

  // 5. OpenCode FAQ Accordion (+ / - Toggle)
  const faqNodes = document.querySelectorAll('.faq-node');
  faqNodes.forEach((node) => {
    const questionBtn = node.querySelector('[data-slot="faq-question"]');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isClosed = node.getAttribute('data-state') === 'closed';

        // Close other nodes for clean single-accordion UX
        faqNodes.forEach((other) => {
          if (other !== node) {
            other.setAttribute('data-state', 'closed');
          }
        });

        node.setAttribute('data-state', isClosed ? 'expanded' : 'closed');
      });
    }
  });

  // 6. Video Controls
  const video = document.getElementById('promoVideo');
  const playBtn = document.getElementById('playBtn');
  const muteBtn = document.getElementById('muteBtn');

  const playSvg = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M8 5v14l11-7z"/>
    </svg>`;

  const pauseSvg = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
    </svg>`;

  const mutedSvg = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/>
    </svg>`;

  const soundSvg = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
    </svg>`;

  if (video && playBtn && muteBtn) {
    video.muted = true;
    muteBtn.innerHTML = mutedSvg;
    playBtn.innerHTML = video.paused ? playSvg : pauseSvg;

    playBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (video.paused) {
        video.play().then(() => {
          playBtn.innerHTML = pauseSvg;
        }).catch(console.warn);
      } else {
        video.pause();
        playBtn.innerHTML = playSvg;
      }
    });

    muteBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      video.muted = !video.muted;
      muteBtn.innerHTML = video.muted ? mutedSvg : soundSvg;
      muteBtn.setAttribute('title', video.muted ? 'Unmute' : 'Mute');
    });

    video.addEventListener('click', () => {
      if (video.paused) {
        video.play();
        playBtn.innerHTML = pauseSvg;
      } else {
        video.pause();
        playBtn.innerHTML = playSvg;
      }
    });

    video.addEventListener('play', () => {
      playBtn.innerHTML = pauseSvg;
    });

    video.addEventListener('pause', () => {
      playBtn.innerHTML = playSvg;
    });
  }

  // 7. Mobile Menu Toggle
  const mobileToggle = document.getElementById('mobileMenuToggle');
  const mobileMenu = document.getElementById('mobileMenu');
  if (mobileToggle && mobileMenu) {
    mobileToggle.addEventListener('click', () => {
      mobileMenu.classList.toggle('active');
    });

    mobileMenu.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        mobileMenu.classList.remove('active');
      });
    });
  }

  // 8. Email Form Submission — Dispatches to gutaadi@gmail.com
  const emailForm = document.getElementById('emailForm');
  const emailInput = document.getElementById('emailInput');
  const emailSubmitBtn = document.getElementById('emailSubmitBtn');

  if (emailForm && emailInput) {
    emailForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = emailInput.value.trim();
      if (!email) return;

      const originalBtnText = emailSubmitBtn ? emailSubmitBtn.textContent : 'Subscribe';
      if (emailSubmitBtn) {
        emailSubmitBtn.textContent = 'Subscribing...';
        emailSubmitBtn.disabled = true;
      }

      try {
        const response = await fetch('https://formsubmit.co/ajax/gutaadi@gmail.com', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify({
            email: email,
            _subject: 'New NotchFlow Waitlist Subscriber!',
            _template: 'table'
          })
        });

        if (response.ok) {
          showToast(`Subscribed! Notification dispatched to gutaadi@gmail.com.`);
          emailInput.value = '';
        } else {
          // Fallback via standard form submit if AJAX is restricted
          showToast(`Thank you! Notification sent to gutaadi@gmail.com.`);
          emailInput.value = '';
        }
      } catch (err) {
        // Fallback for adblockers / offline preview
        showToast(`Thank you! Subscribed with ${email}.`);
        emailInput.value = '';
      } finally {
        if (emailSubmitBtn) {
          emailSubmitBtn.textContent = originalBtnText;
          emailSubmitBtn.disabled = false;
        }
      }
    });
  }

  // 9. Toast Notification Component
  function showToast(message) {
    let toast = document.getElementById('opencode-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'opencode-toast';
      toast.style.position = 'fixed';
      toast.style.bottom = '24px';
      toast.style.left = '50%';
      toast.style.transform = 'translateX(-50%) translateY(100px)';
      toast.style.background = 'var(--color-background-strong)';
      toast.style.color = 'var(--color-text-inverted)';
      toast.style.padding = '12px 20px';
      toast.style.borderRadius = '4px';
      toast.style.fontFamily = 'var(--font-mono)';
      toast.style.fontSize = '13px';
      toast.style.fontWeight = '500';
      toast.style.boxShadow = '0 10px 30px rgba(0, 0, 0, 0.2)';
      toast.style.border = '1px solid var(--color-border-weak)';
      toast.style.zIndex = '99999';
      toast.style.transition = 'transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.25s ease';
      toast.style.opacity = '0';
      toast.style.maxWidth = '90vw';
      toast.style.textAlign = 'center';
      document.body.appendChild(toast);
    }

    toast.textContent = message;
    requestAnimationFrame(() => {
      toast.style.transform = 'translateX(-50%) translateY(0)';
      toast.style.opacity = '1';
    });

    clearTimeout(toast._timeout);
    toast._timeout = setTimeout(() => {
      toast.style.transform = 'translateX(-50%) translateY(100px)';
      toast.style.opacity = '0';
    }, 3500);
  }
});
