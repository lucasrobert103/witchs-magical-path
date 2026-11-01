// Prologue figures and UI icons.
(function (global) {
  'use strict';
  const TAU = Math.PI * 2;
  const { makeCanvas } = Paint;

  // Luminous divine silhouette. kind: 'goddess' | 'god'; reach: 0..1 arm reaching right.
  function figure(o) {
    const W = 512, H = 1024;
    const shape = makeCanvas(W, H), x = shape.getContext('2d');
    x.fillStyle = '#fff'; x.strokeStyle = '#fff'; x.lineCap = 'round'; x.lineJoin = 'round';
    const g = o.kind === 'goddess';
    const cx = W / 2, head = 205;
    // Head
    x.beginPath(); x.ellipse(cx, head, g ? 34 : 37, g ? 42 : 44, 0, 0, TAU); x.fill();
    // Neck + torso
    const sh = g ? 62 : 84;
    x.beginPath();
    x.moveTo(cx - 12, head + 36); x.lineTo(cx + 12, head + 36);
    x.quadraticCurveTo(cx + sh * 0.6, head + 66, cx + sh, head + 82);
    x.quadraticCurveTo(cx + sh * 0.95, head + 170, cx + (g ? 40 : 58), head + 260);
    x.lineTo(cx - (g ? 40 : 58), head + 260);
    x.quadraticCurveTo(cx - sh * 0.95, head + 170, cx - sh, head + 82);
    x.quadraticCurveTo(cx - sh * 0.6, head + 66, cx - 12, head + 36);
    x.fill();
    // Robe / long garment flowing into light
    x.beginPath();
    x.moveTo(cx - (g ? 40 : 58), head + 250);
    x.bezierCurveTo(cx - 110, head + 450, cx - 150, head + 650, cx - 60 - (g ? 80 : 30), H - 40);
    x.quadraticCurveTo(cx, H - 90, cx + 70 + (g ? 120 : 40), H - 30);
    x.bezierCurveTo(cx + 150, head + 640, cx + 105, head + 450, cx + (g ? 40 : 58), head + 250);
    x.fill();
    // Arms
    const arm = (side, reach) => {
      const sx = cx + side * sh * 0.92, sy = head + 92;
      x.lineWidth = g ? 22 : 28;
      x.beginPath(); x.moveTo(sx, sy);
      if (reach > 0) {
        const ex = sx + side * (80 + 60 * reach), ey = sy + 70 - 60 * reach;
        x.quadraticCurveTo(sx + side * 40, sy + 60, ex, ey);
        x.lineTo(ex + side * 90 * reach, ey - 40 * reach);
      } else {
        x.quadraticCurveTo(sx + side * 30, sy + 120, sx + side * 18, sy + 230);
      }
      x.stroke();
    };
    arm(1, o.reach || 0); arm(-1, 0);
    if (g) {
      // Flowing hair streaming to one side.
      x.lineWidth = 14;
      for (let i = 0; i < 9; i++) {
        x.beginPath(); x.moveTo(cx - 10 + i * 3, head - 30);
        x.bezierCurveTo(cx - 70 - i * 8, head + 40 + i * 6, cx - 40 - i * 14, head + 200 + i * 20, cx - 120 - i * 16, head + 330 + i * 26);
        x.stroke();
      }
    } else {
      // Crown of rays.
      x.lineWidth = 7;
      for (let i = -3; i <= 3; i++) { const a = -Math.PI / 2 + i * 0.28; x.beginPath(); x.moveTo(cx + Math.cos(a) * 52, head + Math.sin(a) * 58); x.lineTo(cx + Math.cos(a) * 96, head + Math.sin(a) * 104); x.stroke(); }
    }
    // Compose with glow.
    const out = makeCanvas(W, H), y = out.getContext('2d');
    y.filter = 'blur(28px)'; y.globalAlpha = 0.9; y.drawImage(shape, 0, 0);
    y.filter = 'blur(10px)'; y.globalAlpha = 0.9; y.drawImage(shape, 0, 0);
    y.filter = 'blur(2px)'; y.globalAlpha = 1; y.drawImage(shape, 0, 0);
    y.filter = 'none';
    // Fade the robe into light at the bottom.
    y.globalCompositeOperation = 'destination-in';
    const fade = y.createLinearGradient(0, H * 0.55, 0, H);
    fade.addColorStop(0, 'rgba(0,0,0,1)'); fade.addColorStop(1, 'rgba(0,0,0,0)');
    y.fillStyle = fade; y.fillRect(0, 0, W, H);
    return out;
  }

  function icon(kind) {
    const S = 128; const c = makeCanvas(S, S), x = c.getContext('2d');
    x.translate(S / 2, S / 2);
    x.strokeStyle = '#fff'; x.fillStyle = '#fff'; x.lineWidth = 7; x.lineCap = 'round'; x.lineJoin = 'round';
    switch (kind) {
      case 'magic': {
        x.beginPath();
        for (let i = 0; i < 8; i++) { const a = i * TAU / 8 - Math.PI / 2; const r = i % 2 ? 16 : 44; x.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
        x.closePath(); x.fill();
        x.globalCompositeOperation = 'destination-out'; x.beginPath(); x.arc(0, 0, 8, 0, TAU); x.fill();
        break;
      }
      case 'jump':
        x.beginPath(); x.moveTo(-26, 6); x.lineTo(0, -22); x.lineTo(26, 6); x.stroke();
        x.beginPath(); x.moveTo(-26, 30); x.lineTo(0, 2); x.lineTo(26, 30); x.stroke();
        break;
      case 'interact': {
        // open hand
        const rr = (x0, y0, w, h, r) => { x.beginPath(); x.moveTo(x0 + r, y0); x.arcTo(x0 + w, y0, x0 + w, y0 + h, r); x.arcTo(x0 + w, y0 + h, x0, y0 + h, r); x.arcTo(x0, y0 + h, x0, y0, r); x.arcTo(x0, y0, x0 + w, y0, r); x.fill(); };
        rr(-24, -6, 46, 46, 16);
        rr(-24, -34, 10, 40, 5); rr(-12, -44, 10, 48, 5); rr(0, -42, 10, 46, 5); rr(12, -34, 10, 40, 5);
        x.save(); x.translate(-22, 14); x.rotate(-0.9); rr(-30, -6, 34, 12, 6); x.restore();
        break;
      }
      case 'pause':
        x.fillRect(-20, -26, 13, 52); x.fillRect(7, -26, 13, 52);
        break;
      case 'moon':
        x.beginPath(); x.arc(0, 0, 38, 0, TAU); x.fill();
        x.globalCompositeOperation = 'destination-out'; x.beginPath(); x.arc(18, -10, 34, 0, TAU); x.fill();
        break;
      case 'flame':
        x.beginPath(); x.moveTo(0, 44); x.bezierCurveTo(-46, 30, -30, -14, 0, -46); x.bezierCurveTo(8, -20, 40, -6, 30, 22); x.quadraticCurveTo(22, 44, 0, 44); x.fill();
        x.globalCompositeOperation = 'destination-out'; x.beginPath(); x.moveTo(0, 38); x.bezierCurveTo(-18, 30, -14, 8, 0, -6); x.bezierCurveTo(4, 8, 18, 14, 12, 28); x.quadraticCurveTo(8, 38, 0, 38); x.fill();
        break;
      case 'spark':
        for (const [a, l] of [[0, 46], [Math.PI / 2, 46], [Math.PI / 4, 24], [-Math.PI / 4, 24]]) {
          x.save(); x.rotate(a); x.beginPath(); x.moveTo(-l, 0); x.quadraticCurveTo(0, -7, l, 0); x.quadraticCurveTo(0, 7, -l, 0); x.fill(); x.restore();
        }
        break;
      case 'run': {
        // forward chevrons with speed streaks
        x.beginPath(); x.moveTo(-6, -30); x.lineTo(22, 0); x.lineTo(-6, 30); x.stroke();
        x.beginPath(); x.moveTo(14, -30); x.lineTo(42, 0); x.lineTo(14, 30); x.stroke();
        x.lineWidth = 5;
        for (const [y, l] of [[-16, 26], [0, 34], [16, 26]]) { x.beginPath(); x.moveTo(-44, y); x.lineTo(-44 + l * 0.6, y); x.stroke(); }
        break;
      }
      case 'read':
        x.beginPath(); x.moveTo(-40, -26); x.quadraticCurveTo(-20, -34, 0, -24); x.quadraticCurveTo(20, -34, 40, -26); x.lineTo(40, 30); x.quadraticCurveTo(20, 22, 0, 32); x.quadraticCurveTo(-20, 22, -40, 30); x.closePath(); x.stroke();
        x.beginPath(); x.moveTo(0, -24); x.lineTo(0, 32); x.stroke();
        break;
    }
    return c;
  }

  // Circular gradient ring used by joystick / buttons.
  function ring(o) {
    const S = 256; const c = makeCanvas(S, S), x = c.getContext('2d');
    const g = x.createRadialGradient(S / 2, S / 2, S * 0.2, S / 2, S / 2, S / 2);
    g.addColorStop(0, 'rgba(20,32,26,0.35)'); g.addColorStop(0.85, 'rgba(20,32,26,0.55)'); g.addColorStop(1, 'rgba(20,32,26,0)');
    x.fillStyle = g; x.beginPath(); x.arc(S / 2, S / 2, S / 2, 0, TAU); x.fill();
    x.strokeStyle = 'rgba(232,212,160,0.85)'; x.lineWidth = 5; x.beginPath(); x.arc(S / 2, S / 2, S / 2 - 12, 0, TAU); x.stroke();
    x.strokeStyle = 'rgba(232,212,160,0.35)'; x.lineWidth = 2; x.beginPath(); x.arc(S / 2, S / 2, S / 2 - 24, 0, TAU); x.stroke();
    if (o && o.ticks) for (let i = 0; i < 4; i++) { const a = i * TAU / 4; x.fillStyle = 'rgba(232,212,160,0.8)'; x.beginPath(); x.arc(S / 2 + Math.cos(a) * (S / 2 - 12), S / 2 + Math.sin(a) * (S / 2 - 12), 6, 0, TAU); x.fill(); }
    return c;
  }

  global.Extra = { figure, icon, ring };
})(window);
