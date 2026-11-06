// ========================================================
// Twilight Music — Interactive Platform Logic & Visualizer
// ========================================================

document.addEventListener('DOMContentLoaded', () => {
  detectUserPlatform();
  initVisualizer();
});

// Detect User's Operating System and update Primary CTA button & highlight card
function detectUserPlatform() {
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;
  const platform = navigator.platform || '';

  const labelEl = document.getElementById('primaryOsLabel');
  const btnEl = document.getElementById('primaryDownloadBtn');

  let os = 'Unknown';
  let targetHref = '#downloads';

  if (/android/i.test(userAgent)) {
    os = 'Android';
    targetHref = '/downloads/app-release.apk';
    highlightCard('card-android');
    if (labelEl) labelEl.textContent = 'Download for Android (APK)';
  } else if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
    os = 'iOS';
    targetHref = '/downloads/Twilight-iOS.ipa';
    highlightCard('card-ios');
    if (labelEl) labelEl.textContent = 'Download for iOS (IPA)';
  } else if (/Win/i.test(platform) || /Windows/i.test(userAgent)) {
    os = 'Windows';
    targetHref = '/downloads/Twilight-Windows-x64.zip';
    highlightCard('card-windows');
    if (labelEl) labelEl.textContent = 'Download for Windows PC (x64)';
  } else if (/Mac/i.test(platform)) {
    os = 'macOS';
    highlightCard('card-ios');
    if (labelEl) labelEl.textContent = 'Download Twilight';
  } else {
    highlightCard('card-android');
  }

  if (btnEl && targetHref !== '#downloads') {
    btnEl.href = targetHref;
  }
}

function highlightCard(cardId) {
  const card = document.getElementById(cardId);
  if (card) {
    card.style.borderColor = 'rgba(99, 102, 241, 0.8)';
    card.style.boxShadow = '0 0 30px rgba(99, 102, 241, 0.35)';
    card.style.transform = 'translateY(-4px)';
  }
}

// Canvas Dynamic Audio Visualizer Animation
function initVisualizer() {
  const canvas = document.getElementById('visualizerCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;

  const barCount = 36;
  const barWidth = Math.floor(width / barCount) - 2;

  let bars = Array.from({ length: barCount }, () => Math.random() * height * 0.7 + 6);
  let targets = Array.from({ length: barCount }, () => Math.random() * height * 0.7 + 6);

  function render() {
    ctx.clearRect(0, 0, width, height);

    for (let i = 0; i < barCount; i++) {
      // Smooth interpolation towards random targets
      bars[i] += (targets[i] - bars[i]) * 0.12;
      if (Math.abs(targets[i] - bars[i]) < 1.5) {
        targets[i] = Math.random() * (height * 0.85) + 4;
      }

      const barHeight = Math.max(3, bars[i]);
      const x = i * (barWidth + 2);
      const y = height - barHeight;

      // Beautiful gradient for each bar
      const grad = ctx.createLinearGradient(0, y, 0, height);
      grad.addColorStop(0, '#ec4899');
      grad.addColorStop(0.5, '#a855f7');
      grad.addColorStop(1, '#6366f1');

      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.roundRect(x, y, barWidth, barHeight, 3);
      ctx.fill();
    }

    requestAnimationFrame(render);
  }

  render();
}
