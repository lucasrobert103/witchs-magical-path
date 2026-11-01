// Art for solid 3D trees (bark, leaf clumps) and the Vale do Rio.
(function (global) {
  'use strict';
  const { rng, rgba, mix, shade, makeCanvas, noise2, tileNoise, blobPath, glow, dabs } = Paint;
  const TAU = Math.PI * 2;

  // Seamless bark: vertical fissures, plates and lichen.
  function barkTile(o) {
    const W = 512, H = 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 5);
    const n = noise2(o.seed || 5);
    const img = x.createImageData(W, H);
    const base = Paint.hex(o.base), dark = Paint.hex(o.dark), light = Paint.hex(o.light);
    for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
      // Stretched noise gives long vertical ridges.
      const v = tileNoise(n, xx / W * 10, yy / H * 2.5, 10, 2.5, 4);
      const fine = tileNoise(n, xx / W * 40 + 9, yy / H * 12 + 9, 40, 12, 2);
      const ridge = Math.pow(Math.abs(Math.sin((v * 2.2 + xx / W * 6) * Math.PI)), 0.6);
      let t = ridge * 0.75 + fine * 0.35;
      const i = (yy * W + xx) * 4;
      for (let ch = 0; ch < 3; ch++) {
        const col = t < 0.45 ? dark[ch] + (base[ch] - dark[ch]) * (t / 0.45) : base[ch] + (light[ch] - base[ch]) * Math.min(1, (t - 0.45) / 0.55);
        img.data[i + ch] = col;
      }
      img.data[i + 3] = 255;
    }
    x.putImageData(img, 0, 0);
    const draw = fn => { for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) { x.save(); x.translate(ox, oy); fn(); x.restore(); } };
    // Lichen and moss specks.
    for (let k = 0; k < 260; k++) {
      const px = r() * W, py = r() * H, s = 2 + r() * 6;
      const col = ['#6f8a4a', '#8fa66a', '#b9c49a', '#56703a'][k % 4];
      draw(() => { x.fillStyle = rgba(col, 0.55); x.beginPath(); x.ellipse(px, py, s, s * 0.6, r(), 0, TAU); x.fill(); });
    }
    return c;
  }

  // Painterly cluster of leaves, used as camera-facing canopy puffs.
  function leafClump(o) {
    const S = o.size || 256;
    const c = makeCanvas(S, S), x = c.getContext('2d');
    const r = rng(o.seed || 1);
    const L = o.leaves;
    const cx = S / 2, cy = S / 2;
    // Dark mass.
    x.fillStyle = L[0];
    for (let i = 0; i < 9; i++) {
      const a = r() * TAU, d = r() * S * 0.16;
      blobPath(x, cx + Math.cos(a) * d, cy + Math.sin(a) * d + S * 0.04, S * (0.2 + r() * 0.08), S * (0.17 + r() * 0.07), r, 0.35, 16);
      x.fill();
    }
    // Mid clusters with shading.
    for (let i = 0; i < 14; i++) {
      const a = r() * TAU, d = Math.sqrt(r()) * S * 0.22;
      const px = cx + Math.cos(a) * d, py = cy + Math.sin(a) * d * 0.85;
      const s = S * (0.08 + r() * 0.07);
      const col = L[1 + (i % 3)];
      x.save();
      blobPath(x, px, py, s, s * 0.85, r, 0.3, 14);
      x.fillStyle = col; x.fill(); x.clip();
      x.fillStyle = rgba(shade(col, -0.35), 0.7);
      x.beginPath(); x.ellipse(px + s * 0.35, py + s * 0.45, s, s * 0.7, 0, 0, TAU); x.fill();
      dabs(x, r, px - s, py - s, s * 1.2, s, 18, [L[4], shade(col, 0.2)], s * 0.09, 0.8);
      x.restore();
    }
    // Leafy rim.
    for (let k = 0; k < 120; k++) {
      const a = r() * TAU, d = S * (0.28 + r() * 0.12);
      const px = cx + Math.cos(a) * d * (0.9 + r() * 0.15), py = cy + Math.sin(a) * d * 0.85;
      const lit = Math.sin(a) < -0.1 && Math.cos(a) < 0.4;
      x.fillStyle = rgba(lit ? L[4] : L[1 + (k % 3)], 0.95);
      x.beginPath(); x.ellipse(px, py, S * 0.022, S * 0.011, a + 1.3, 0, TAU); x.fill();
    }
    dabs(x, r, cx - S * 0.3, cy - S * 0.32, S * 0.4, S * 0.3, 26, [L[5] || L[4]], S * 0.008, 0.7);
    // Soft fade at the very edge so puffs blend into each other.
    return c;
  }

  // Distant mountain range with snow and waterfalls (seamless horizontally is not needed).
  function mountains(o) {
    const W = 2048, H = 640;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 9);
    const layers = o.layers || 3;
    for (let L = 0; L < layers; L++) {
      const far = 1 - L / layers;
      const top = H * (0.08 + L * 0.12);
      const pts = [];
      let px = -20;
      while (px < W + 40) {
        const peak = r() < 0.35;
        pts.push([px, top + (peak ? r() * H * 0.12 : H * (0.12 + r() * 0.25))]);
        px += 30 + r() * 90;
      }
      x.beginPath(); x.moveTo(-20, H);
      for (const p of pts) x.lineTo(p[0], p[1]);
      x.lineTo(W + 40, H); x.closePath();
      const g = x.createLinearGradient(0, top, 0, H);
      g.addColorStop(0, mix(o.rock, o.haze, far * 0.6));
      g.addColorStop(1, mix(o.base, o.haze, far * 0.75));
      x.fillStyle = g; x.fill();
      x.save(); x.clip();
      // Snow caps on the upper rocks.
      if (L < 2) {
        for (let i = 1; i < pts.length - 1; i++) {
          const p = pts[i];
          if (p[1] > top + H * 0.14) continue;
          x.fillStyle = rgba(mix('#f4f6fb', o.haze, far * 0.4), 0.92);
          x.beginPath(); x.moveTo(p[0], p[1]);
          x.lineTo(p[0] - 30 - r() * 30, p[1] + 40 + r() * 40); x.lineTo(p[0] - 8, p[1] + 30); x.lineTo(p[0] + 6, p[1] + 50 + r() * 20); x.lineTo(p[0] + 34 + r() * 20, p[1] + 36 + r() * 30);
          x.closePath(); x.fill();
        }
      }
      // Ridge strokes.
      for (let k = 0; k < 160; k++) {
        const sx = r() * W, sy = top + r() * (H - top);
        x.strokeStyle = rgba(r() < 0.5 ? shade(o.rock, -0.25) : shade(o.rock, 0.2), 0.18);
        x.lineWidth = 2;
        x.beginPath(); x.moveTo(sx, sy); x.lineTo(sx + (r() - 0.5) * 30, sy + 20 + r() * 40); x.stroke();
      }
      // Forested lower slopes on the nearest layer.
      if (L === layers - 1) {
        for (let k = 0; k < 900; k++) {
          const tx = r() * W, ty = H * (0.62 + r() * 0.38);
          x.fillStyle = rgba(mix(o.forest, o.haze, 0.25 + r() * 0.2), 0.9);
          x.beginPath(); x.ellipse(tx, ty, 6 + r() * 8, 8 + r() * 10, 0, 0, TAU); x.fill();
        }
      }
      x.restore();
      // Mist band.
      const m = x.createLinearGradient(0, H * (0.45 + L * 0.12), 0, H);
      m.addColorStop(0, rgba(o.haze, 0)); m.addColorStop(1, rgba(o.haze, 0.55));
      x.fillStyle = m; x.fillRect(0, H * (0.45 + L * 0.12), W, H);
    }
    // Waterfall thread.
    x.strokeStyle = 'rgba(240,248,255,0.7)'; x.lineWidth = 4;
    x.beginPath(); x.moveTo(W * 0.46, H * 0.3); x.bezierCurveTo(W * 0.465, H * 0.45, W * 0.455, H * 0.6, W * 0.47, H * 0.8); x.stroke();
    return c;
  }

  // Rolling wooded hills (mid-distance backdrop).
  function hills(o) {
    const W = 2048, H = 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 11);
    for (let L = 0; L < 3; L++) {
      const top = H * (0.25 + L * 0.18);
      x.beginPath(); x.moveTo(0, H);
      for (let i = 0; i <= 32; i++) {
        const px = i / 32 * W;
        x.lineTo(px, top + Math.sin(i * 0.7 + L * 2) * H * 0.07 + Math.sin(i * 1.9 + L) * H * 0.04);
      }
      x.lineTo(W, H); x.closePath();
      const col = mix(o.green, o.haze, 0.55 - L * 0.2);
      x.fillStyle = col; x.fill();
      x.save(); x.clip();
      for (let k = 0; k < 1300; k++) {
        const tx = r() * W, ty = top - 20 + r() * (H - top);
        const tc = [o.green, o.autumn, o.gold, shade(o.green, -0.2)][k % 4];
        x.fillStyle = rgba(mix(tc, o.haze, 0.5 - L * 0.18), 0.9);
        x.beginPath(); x.ellipse(tx, ty, 7 + r() * 10, 6 + r() * 8, 0, 0, TAU); x.fill();
      }
      x.restore();
    }
    return c;
  }

  function branches(o) {
    const W = 256, H = 128;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 3);
    for (let i = 0; i < 4; i++) {
      const y0 = H * (0.55 + i * 0.09), x0 = W * (0.08 + r() * 0.08), x1 = W * (0.84 + r() * 0.1);
      const g = x.createLinearGradient(0, y0 - 8, 0, y0 + 8);
      g.addColorStop(0, '#8b6a4c'); g.addColorStop(1, '#3d2b1f');
      x.strokeStyle = g; x.lineWidth = 9 - i; x.lineCap = 'round';
      x.beginPath(); x.moveTo(x0, y0 + (r() - 0.5) * 10); x.quadraticCurveTo(W * 0.5, y0 - 12 + r() * 24, x1, y0 + (r() - 0.5) * 16); x.stroke();
      // twigs
      x.lineWidth = 3;
      for (let k = 0; k < 3; k++) { const tx = x0 + (x1 - x0) * (0.2 + r() * 0.6); x.beginPath(); x.moveTo(tx, y0); x.lineTo(tx + 10 + r() * 14, y0 - 12 - r() * 16); x.stroke(); }
    }
    for (let k = 0; k < 10; k++) { x.fillStyle = ['#c0702c', '#d99a3c', '#6d8f3a'][k % 3]; x.beginPath(); x.ellipse(W * (0.1 + r() * 0.8), H * (0.5 + r() * 0.4), 6, 3, r() * 3, 0, TAU); x.fill(); }
    return c;
  }

  function seedPlant(o) {
    const W = 256, H = 320;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 21);
    // stems
    for (let i = 0; i < 7; i++) {
      const bx = W / 2 + (r() - 0.5) * 30, tx = W / 2 + (r() - 0.5) * 140, ty = H * (0.15 + r() * 0.25);
      x.strokeStyle = '#4e6b2c'; x.lineWidth = 4;
      x.beginPath(); x.moveTo(bx, H - 6); x.quadraticCurveTo((bx + tx) / 2, H * 0.6, tx, ty); x.stroke();
      // leaves
      for (let k = 0; k < 4; k++) {
        const t = 0.3 + k * 0.17, lx = bx + (tx - bx) * t, ly = H - 6 + (ty - H + 6) * t;
        x.fillStyle = k % 2 ? '#6f9a3c' : '#5a8434';
        x.beginPath(); x.ellipse(lx + (k % 2 ? 12 : -12), ly, 16, 6, k % 2 ? -0.5 : 0.5, 0, TAU); x.fill();
      }
      // seed heads
      x.fillStyle = '#d8b25a';
      for (let k = 0; k < 9; k++) { x.beginPath(); x.ellipse(tx + (r() - 0.5) * 16, ty + (r() - 0.5) * 16, 4, 6, r(), 0, TAU); x.fill(); }
      x.fillStyle = '#f2d98a'; x.beginPath(); x.arc(tx - 3, ty - 4, 3, 0, TAU); x.fill();
    }
    // fallen seeds on the ground
    for (let k = 0; k < 18; k++) { x.fillStyle = k % 3 ? '#c9a24f' : '#f0d27c'; x.beginPath(); x.ellipse(W * (0.25 + r() * 0.5), H - 8 - r() * 8, 3, 2, r() * 3, 0, TAU); x.fill(); }
    return c;
  }

  // Lean-to shelter of gathered branches; stage 1 bare, stage 2 covered with leaves.
  function shelter(o) {
    const W = 640, H = 448;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 31);
    const by = H - 10;
    // ridge pole on two forked posts
    const post = (px) => {
      x.strokeStyle = '#4a3423'; x.lineWidth = 14; x.lineCap = 'round';
      x.beginPath(); x.moveTo(px, by); x.lineTo(px + 6, H * 0.22); x.stroke();
      x.lineWidth = 8; x.beginPath(); x.moveTo(px + 6, H * 0.26); x.lineTo(px - 16, H * 0.14); x.moveTo(px + 6, H * 0.26); x.lineTo(px + 26, H * 0.14); x.stroke();
    };
    // slanted poles (back roof)
    for (let i = 0; i < 16; i++) {
      const t = i / 15;
      const tx = W * (0.14 + t * 0.72), ty = H * 0.2;
      const bx = tx + W * 0.12, b2 = by - 4;
      const g = x.createLinearGradient(tx, ty, bx, b2);
      g.addColorStop(0, '#8b6a4c'); g.addColorStop(1, '#3d2b1f');
      x.strokeStyle = g; x.lineWidth = 10 + r() * 6;
      x.beginPath(); x.moveTo(tx - 10, ty - 10); x.lineTo(bx, b2); x.stroke();
    }
    post(W * 0.14); post(W * 0.86);
    x.strokeStyle = '#5b412c'; x.lineWidth = 12;
    x.beginPath(); x.moveTo(W * 0.08, H * 0.2); x.lineTo(W * 0.94, H * 0.21); x.stroke();
    if (o.stage >= 2) {
      // leaf thatch
      for (let k = 0; k < 900; k++) {
        const t = r(), u = r();
        const px = W * (0.12 + t * 0.76) + u * W * 0.12, py = H * 0.2 + u * (by - H * 0.2);
        x.fillStyle = rgba(['#5d7a33', '#7a8f3c', '#b0732e', '#8a5a26', '#4a6a2c'][k % 5], 0.92);
        x.beginPath(); x.ellipse(px, py, 9 + r() * 6, 4 + r() * 3, -0.9 + r() * 0.4, 0, TAU); x.fill();
      }
      // bedding inside
      x.fillStyle = 'rgba(30,20,12,0.55)';
      x.beginPath(); x.ellipse(W * 0.48, by - 6, W * 0.3, 18, 0, 0, TAU); x.fill();
    }
    return c;
  }

  // Soil plot decal: dark loosened earth, optional wet look and furrows.
  function soilPlot(o) {
    const W = 512, H = 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 41);
    const g = x.createRadialGradient(W / 2, H / 2, W * 0.2, W / 2, H / 2, W * 0.5);
    g.addColorStop(0, o.wet ? '#2c1f16' : '#4a3626'); g.addColorStop(0.85, o.wet ? '#33251a' : '#56402c'); g.addColorStop(1, 'rgba(70,52,36,0)');
    x.fillStyle = g; x.fillRect(0, 0, W, H);
    for (let row = 0; row < 3; row++) {
      const y = H * (0.3 + row * 0.2);
      x.strokeStyle = o.wet ? 'rgba(15,10,6,0.7)' : 'rgba(35,24,15,0.7)'; x.lineWidth = 16;
      x.beginPath(); x.moveTo(W * 0.15, y); x.bezierCurveTo(W * 0.4, y - 6, W * 0.6, y + 6, W * 0.85, y); x.stroke();
      x.strokeStyle = o.wet ? 'rgba(120,150,170,0.18)' : 'rgba(140,110,80,0.35)'; x.lineWidth = 4;
      x.beginPath(); x.moveTo(W * 0.15, y - 10); x.bezierCurveTo(W * 0.4, y - 16, W * 0.6, y - 4, W * 0.85, y - 10); x.stroke();
    }
    for (let k = 0; k < 400; k++) { x.fillStyle = rgba(r() < 0.5 ? '#6b513a' : '#20160f', 0.5); x.beginPath(); x.arc(W * (0.12 + r() * 0.76), H * (0.15 + r() * 0.7), 1 + r() * 3, 0, TAU); x.fill(); }
    return c;
  }

  function sprouts(o) {
    const W = 256, H = 128;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 51);
    for (let i = 0; i < 7; i++) {
      const px = W * (0.1 + i * 0.13 + (r() - 0.5) * 0.04), h = 20 + r() * 26;
      x.strokeStyle = '#5e8a34'; x.lineWidth = 3;
      x.beginPath(); x.moveTo(px, H - 4); x.quadraticCurveTo(px + 4, H - h * 0.6, px, H - h); x.stroke();
      x.fillStyle = '#8cc04f';
      x.beginPath(); x.ellipse(px - 7, H - h, 8, 4, 0.5, 0, TAU); x.fill();
      x.beginPath(); x.ellipse(px + 7, H - h - 2, 8, 4, -0.5, 0, TAU); x.fill();
    }
    return c;
  }

  function reeds(o) {
    const W = 192, H = 256;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 61);
    for (let i = 0; i < 26; i++) {
      const bx = W * (0.1 + r() * 0.8), h = H * (0.4 + r() * 0.55), lean = (r() - 0.5) * 30;
      x.strokeStyle = mix('#4f6a2c', '#a3a35a', r()); x.lineWidth = 3;
      x.beginPath(); x.moveTo(bx, H); x.quadraticCurveTo(bx + lean * 0.3, H - h * 0.5, bx + lean, H - h); x.stroke();
      if (r() < 0.35) { x.fillStyle = '#6b4a2c'; x.beginPath(); x.ellipse(bx + lean, H - h + 10, 4, 12, lean * 0.01, 0, TAU); x.fill(); }
    }
    return c;
  }

  // Leaf thatch for the shelter roof: overlapping leaves with ragged edges.
  function thatch(o) {
    const W = 512, H = 384;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 71);
    x.fillStyle = '#3a2a1a';
    x.beginPath(); x.moveTo(10, 14); x.lineTo(W - 10, 8); x.lineTo(W - 4, H - 18); x.lineTo(6, H - 10); x.closePath(); x.fill();
    for (let row = 0; row < 14; row++) {
      for (let k = 0; k < 46; k++) {
        const px = 10 + r() * (W - 20), py = 10 + row * (H - 20) / 14 + r() * 18;
        const col = ['#5d7a33', '#7a8f3c', '#b0732e', '#8a5a26', '#4a6a2c', '#c98a3a'][Math.floor(r() * 6)];
        x.fillStyle = col;
        x.save(); x.translate(px, py); x.rotate(1.2 + (r() - 0.5) * 0.8);
        x.beginPath(); x.ellipse(0, 0, 18 + r() * 10, 6 + r() * 3, 0, 0, TAU); x.fill();
        x.strokeStyle = 'rgba(30,20,10,0.4)'; x.lineWidth = 1.5; x.beginPath(); x.moveTo(-16, 0); x.lineTo(16, 0); x.stroke();
        x.restore();
      }
    }
    const g = x.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, 'rgba(255,230,170,0.12)'); g.addColorStop(1, 'rgba(0,0,0,0.25)');
    x.globalCompositeOperation = 'source-atop'; x.fillStyle = g; x.fillRect(0, 0, W, H);
    return c;
  }

  global.Valley = { thatch, barkTile, leafClump, mountains, hills, branches, seedPlant, shelter, soilPlot, sprouts, reeds };
})(window);
