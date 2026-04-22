'use strict';

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

const startBtn      = document.getElementById('start-btn');
const startScreen   = document.getElementById('start-screen');
const compassScreen = document.getElementById('compass-screen');
const needle        = document.getElementById('needle');
const degreesEl     = document.getElementById('degrees');
const statusEl      = document.getElementById('status');
const quipEl        = document.getElementById('quip');

// Build SVG tick marks
const ticksG = document.getElementById('ticks');
for (let i = 0; i < 36; i++) {
  const major = i % 9 === 0;
  const line  = document.createElementNS('http://www.w3.org/2000/svg', 'line');
  line.setAttribute('y1', major ? '-95' : '-101');
  line.setAttribute('y2', '-109');
  line.setAttribute('stroke-width', major ? '2' : '1');
  line.classList.add('tick');
  if (major) line.classList.add('major');
  line.setAttribute('transform', `rotate(${i * 10})`);
  ticksG.appendChild(line);
}

// ── Permission & launch ──────────────────────────────────────────────────────

startBtn.addEventListener('click', () => {
  if (typeof DeviceOrientationEvent !== 'undefined' &&
      typeof DeviceOrientationEvent.requestPermission === 'function') {
    // iOS 13+ requires explicit permission triggered by a user gesture
    DeviceOrientationEvent.requestPermission()
      .then(state => {
        if (state === 'granted') launch();
        else alert('Compass access denied.\nGo to Settings → Safari → Motion & Orientation Access and enable it.');
      })
      .catch(err => alert('Error requesting compass: ' + err));
  } else {
    // Android or older iOS — no permission prompt needed
    launch();
  }
});

function launch() {
  startScreen.hidden   = true;
  compassScreen.hidden = false;
  window.addEventListener('deviceorientation', onOrientation, true);
}

// ── Compass updates ──────────────────────────────────────────────────────────

// Accumulated heading avoids the needle spinning the long way past 0°/360°
let accHeading = 0;
let lastRaw    = null;

function onOrientation(e) {
  let raw;
  if (e.webkitCompassHeading != null) {
    raw = e.webkitCompassHeading;          // iOS: 0 = North, increases clockwise
  } else if (e.alpha != null) {
    raw = (360 - e.alpha) % 360;           // Android fallback
  } else {
    return;
  }

  if (lastRaw !== null) {
    let delta = raw - lastRaw;
    if (delta >  180) delta -= 360;        // always take the short arc
    if (delta < -180) delta += 360;
    accHeading += delta;
  }
  lastRaw = raw;

  render(raw);
}

function render(heading) {
  // Rotate needle so it always points to magnetic north
  needle.style.transform = `rotate(${-accHeading}deg)`;

  // Heading readout (0–360)
  degreesEl.textContent = String(Math.round(heading)).padStart(3, '0') + '°';

  // proximity: 0 = far from north, 1 = exactly north (within 25°)
  const dist      = Math.min(heading, 360 - heading);
  const proximity = Math.max(0, 1 - dist / 25);

  // Background smoothly fades black → white
  const v = Math.round(proximity * 255);
  document.body.style.backgroundColor = `rgb(${v},${v},${v})`;

  // Foreground flips at the midpoint so text stays readable
  const light = proximity > 0.5;
  const root  = document.documentElement;
  root.style.setProperty('--fg',     light ? '#000000'              : '#ffffff');
  root.style.setProperty('--fg-dim', light ? 'rgba(0,0,0,0.45)'    : 'rgba(255,255,255,0.45)');

  // Fun messages
  if (proximity > 0.95) {
    statusEl.textContent = 'YOU FOUND NORTH! 🎉';
    quipEl.textContent   = 'Your phone is smarter than you thought!';
  } else if (proximity > 0.3) {
    statusEl.textContent = 'Getting warm… 🤔';
    quipEl.textContent   = '';
  } else if (heading < 90) {
    statusEl.textContent = 'Slightly lost 🙃';
    quipEl.textContent   = '';
  } else if (heading < 180) {
    statusEl.textContent = 'Going East, buddy 😅';
    quipEl.textContent   = '';
  } else if (heading < 270) {
    statusEl.textContent = 'Hello, South! 🤪';
    quipEl.textContent   = '';
  } else {
    statusEl.textContent = 'Almost! Keep spinning 🌀';
    quipEl.textContent   = '';
  }
}
