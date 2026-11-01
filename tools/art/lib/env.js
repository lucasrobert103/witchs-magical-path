// Painterly environment sprites and textures for the Asterion forest.
(function (global) {
  'use strict';
  const { rng, rgba, mix, shade, makeCanvas, noise2, tileNoise, blobPath, smoothClosed, glow, dabs } = Paint;
  const TAU = Math.PI * 2;

  // ------------------------------------------------------------ helpers
  // Polygon for a tapered limb along a centerline.
  function limbPoly(pts, w0, w1) {
    const L = [], R = [];
    for (let i = 0; i < pts.length; i++) {
      const p = pts[i];
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
      let dx = b[0] - a[0], dy = b[1] - a[1];
      const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
      const w = (w0 + (w1 - w0) * (i / (pts.length - 1))) / 2;
      L.push([p[0] - dy * w, p[1] + dx * w]);
      R.push([p[0] + dy * w, p[1] - dx * w]);
    }
    return L.concat(R.reverse());
  }
  function polyPath(ctx, poly) {
    ctx.beginPath(); ctx.moveTo(poly[0][0], poly[0][1]);
    for (let i = 1; i < poly.length; i++) ctx.lineTo(poly[i][0], poly[i][1]);
    ctx.closePath();
  }
  function curve(p0, p1, p2, n) {
    const out = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n, u = 1 - t;
      out.push([u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]]);
    }
    return out;
  }
  function barkFill(ctx, r, x0, y0, w, h, pal) {
    const g = ctx.createLinearGradient(x0, 0, x0 + w, 0);
    g.addColorStop(0, pal[2]); g.addColorStop(0.35, pal[1]); g.addColorStop(0.75, pal[0]); g.addColorStop(1, shade(pal[0], -0.35));
    ctx.fillStyle = g; ctx.fillRect(x0, y0, w, h);
    // Vertical bark strokes.
    for (let i = 0; i < w * h / 260; i++) {
      const x = x0 + r() * w, y = y0 + r() * h, l = 8 + r() * 40;
      ctx.strokeStyle = rgba(r() < 0.6 ? shade(pal[0], -0.4) : pal[2], 0.25 + r() * 0.35);
      ctx.lineWidth = 1 + r() * 2.5;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.quadraticCurveTo(x + (r() - 0.5) * 6, y + l / 2, x + (r() - 0.5) * 4, y + l); ctx.stroke();
    }
  }

  // ------------------------------------------------------------ trees
  // Broad forest tree with roots and a painterly canopy.
  function tree(o) {
    const W = o.w || 640, H = o.h || 896;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 1);
    const bark = o.bark || ['#3b2a20', '#5b4231', '#8a6b4f'];
    const base = [W / 2, H - 18];
    const trunkTop = [W / 2 + (r() - 0.5) * 40, H * (o.trunk || 0.5)];
    const tw = W * (o.girth || 0.13);
    // Canopy layout (computed first so branches can reach clusters).
    const cx = W / 2, cy = H * (o.canopyY || 0.3), crx = W * 0.44, cry = H * (o.canopyH || 0.26);
    const clusters = [];
    for (let i = 0; i < (o.clusters || 34); i++) {
      const a = r() * TAU, d = Math.sqrt(r());
      clusters.push({ x: cx + Math.cos(a) * crx * d * 0.9, y: cy + Math.sin(a) * cry * d * 0.95, s: (0.16 + r() * 0.12) * W, k: r() });
    }
    clusters.sort((a, b) => a.y - b.y);
    // Back canopy (dark) behind trunk branches.
    const leaves = o.leaves;
    for (const cl of clusters) {
      x.fillStyle = leaves[0];
      blobPath(x, cl.x + 6, cl.y + 10, cl.s * 0.7, cl.s * 0.6, r, 0.35, 16); x.fill();
    }
    // Roots.
    const roots = [];
    for (let i = 0; i < 5; i++) {
      const s = i < 2 ? -1 : (i < 4 ? 1 : (r() < 0.5 ? -1 : 1));
      const spread = (0.07 + r() * 0.11) * W * s;
      roots.push(curve([base[0] + s * tw * 0.2, base[1] - tw * 0.9], [base[0] + spread * 0.5, base[1] - 10 - r() * 20], [base[0] + spread, base[1] + 4 - r() * 10], 12));
    }
    // Branches from trunk top to clusters.
    const branches = [];
    for (let i = 0; i < (o.branches || 6); i++) {
      const tgt = clusters[Math.floor(r() * clusters.length)];
      const st = [trunkTop[0] + (r() - 0.5) * tw * 0.5, trunkTop[1] + r() * H * 0.08];
      branches.push({ pts: curve(st, [lerp(st[0], tgt.x, 0.3), lerp(st[1], tgt.y, 0.7) + 20], [tgt.x, tgt.y + tgt.s * 0.2], 14), w: tw * (0.28 + r() * 0.25) });
    }
    function lerp(a, b, t) { return a + (b - a) * t; }
    const trunkPts = curve(base, [lerp(base[0], trunkTop[0], 0.5) + (r() - 0.5) * 50, lerp(base[1], trunkTop[1], 0.5)], trunkTop, 20);
    const shapes = [];
    for (const b of branches) shapes.push(limbPoly(b.pts, b.w, b.w * 0.25));
    shapes.push(limbPoly(trunkPts, tw * 1.25, tw * 0.75));
    for (const rt of roots) shapes.push(limbPoly(rt, tw * 0.45, tw * 0.06));
    // Fill wood with bark texture.
    x.save();
    x.beginPath();
    for (const s of shapes) { x.moveTo(s[0][0], s[0][1]); for (const p of s) x.lineTo(p[0], p[1]); x.closePath(); }
    x.fillStyle = bark[0]; x.fill('nonzero');
    x.clip('nonzero');
    barkFill(x, r, base[0] - tw * 2.5, 0, tw * 5, H, bark);
    // Roots and limbs share bark; add shadow at base and moss.
    const g = x.createLinearGradient(0, H - tw * 1.4, 0, H);
    g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(10,15,8,0.6)');
    x.fillStyle = g; x.fillRect(0, H - tw * 1.4, W, tw * 1.4);
    if (o.moss) dabs(x, r, base[0] - tw * 1.2, H * 0.55, tw * 2.4, H * 0.45, 260, ['#5d7a3a', '#7a9446', '#4a6530'], 4, 0.5);
    x.restore();
    // Front canopy clusters: base, shadow, light dabs, rim leaves.
    for (const cl of clusters) {
      const col = cl.k < 0.33 ? leaves[1] : (cl.k < 0.66 ? leaves[2] : leaves[3]);
      x.save();
      blobPath(x, cl.x, cl.y, cl.s * 0.62, cl.s * 0.52, r, 0.3, 18);
      x.fillStyle = col; x.fill();
      x.clip();
      // Shadow lower right.
      x.fillStyle = rgba(shade(col, -0.35), 0.75);
      x.beginPath(); x.ellipse(cl.x + cl.s * 0.25, cl.y + cl.s * 0.32, cl.s * 0.6, cl.s * 0.45, 0, 0, TAU); x.fill();
      // Light upper left.
      dabs(x, r, cl.x - cl.s * 0.55, cl.y - cl.s * 0.55, cl.s * 0.7, cl.s * 0.55, 34, [leaves[4], shade(col, 0.2)], cl.s * 0.06, 0.8);
      x.restore();
      // Leafy rim.
      for (let k = 0; k < 18; k++) {
        const a = r() * TAU;
        const ex = cl.x + Math.cos(a) * cl.s * 0.6, ey = cl.y + Math.sin(a) * cl.s * 0.5;
        x.fillStyle = rgba(Math.sin(a) < -0.2 && Math.cos(a) < 0.3 ? leaves[4] : col, 0.95);
        x.beginPath(); x.ellipse(ex, ey, cl.s * 0.07, cl.s * 0.035, a + 1.2, 0, TAU); x.fill();
      }
    }
    // Sun specks.
    dabs(x, r, cx - crx, cy - cry, crx * 1.4, cry * 1.2, 60, [leaves[5] || leaves[4]], W * 0.006, 0.7);
    return c;
  }

  // Distant soft tree silhouette for fog layers.
  function farTree(o) {
    const W = o.w || 256, H = o.h || 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 3);
    x.fillStyle = o.color;
    x.fillRect(W / 2 - W * 0.04, H * 0.35, W * 0.08, H * 0.65);
    for (let i = 0; i < 16; i++) {
      const a = r() * TAU, d = Math.sqrt(r());
      blobPath(x, W / 2 + Math.cos(a) * W * 0.3 * d, H * 0.3 + Math.sin(a) * H * 0.2 * d, W * (0.12 + r() * 0.1), W * (0.1 + r() * 0.08), r, 0.3, 14);
      x.fill();
    }
    return c;
  }

  // ------------------------------------------------------------ small plants
  function bush(o) {
    const W = o.w || 320, H = o.h || 224;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 5);
    const L = o.leaves;
    for (let layer = 0; layer < 3; layer++) {
      for (let i = 0; i < 9; i++) {
        const cx = W * (0.2 + r() * 0.6), cy = H * (0.45 + r() * 0.3) + layer * H * 0.06;
        const s = W * (0.14 + r() * 0.1);
        x.save();
        blobPath(x, cx, cy, s, s * 0.8, r, 0.35, 14);
        x.fillStyle = L[layer + 1] || L[1]; x.fill(); x.clip();
        x.fillStyle = rgba(shade(L[layer + 1] || L[1], -0.35), 0.6);
        x.beginPath(); x.ellipse(cx + s * 0.3, cy + s * 0.45, s, s * 0.6, 0, 0, TAU); x.fill();
        dabs(x, r, cx - s, cy - s, s * 1.2, s * 0.9, 20, [L[4]], s * 0.08, 0.7);
        x.restore();
      }
    }
    if (o.berries) for (let i = 0; i < 14; i++) { x.fillStyle = o.berries; x.beginPath(); x.arc(W * (0.2 + r() * 0.6), H * (0.4 + r() * 0.4), 3 + r() * 2, 0, TAU); x.fill(); }
    return c;
  }

  function fern(o) {
    const W = o.w || 256, H = o.h || 192;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 7);
    for (let i = 0; i < 11; i++) {
      const a = -Math.PI / 2 + (i / 10 - 0.5) * 2.6 + (r() - 0.5) * 0.2;
      const len = H * (0.6 + r() * 0.35);
      const pts = [];
      for (let k = 0; k <= 12; k++) {
        const t = k / 12;
        const bend = t * t * 0.9 * Math.sign(Math.cos(a));
        pts.push([W / 2 + Math.cos(a + bend) * len * t, H - 4 + Math.sin(a + bend * 0.3) * len * t + t * t * len * 0.35]);
      }
      const col = i % 3 === 0 ? o.c2 : o.c1;
      x.strokeStyle = shade(col, -0.3); x.lineWidth = 2;
      x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.stroke();
      for (let k = 2; k < pts.length; k++) {
        const t = k / 12, p = pts[k], q = pts[k - 1];
        const dx = p[0] - q[0], dy = p[1] - q[1], l = Math.hypot(dx, dy) || 1;
        const w = (1 - t) * 18 + 4;
        for (const s of [-1, 1]) {
          x.fillStyle = s < 0 ? col : shade(col, -0.15);
          x.beginPath(); x.ellipse(p[0] - dy / l * w * 0.5 * s, p[1] + dx / l * w * 0.5 * s, w * 0.55, 3.2, Math.atan2(dy, dx) + s * 0.9, 0, TAU); x.fill();
        }
      }
    }
    return c;
  }

  function grassTuft(o) {
    const W = o.w || 128, H = o.h || 128;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 9);
    for (let i = 0; i < (o.blades || 26); i++) {
      const bx = W * (0.15 + r() * 0.7), h = H * (0.35 + r() * 0.6), lean = (r() - 0.5) * W * 0.4;
      const col = mix(o.c1, o.c2, r());
      const g = x.createLinearGradient(0, H, 0, H - h);
      g.addColorStop(0, shade(col, -0.45)); g.addColorStop(1, shade(col, 0.15));
      x.fillStyle = g;
      x.beginPath(); x.moveTo(bx - 3, H); x.quadraticCurveTo(bx + lean * 0.3, H - h * 0.6, bx + lean, H - h); x.quadraticCurveTo(bx + lean * 0.3 + 2, H - h * 0.5, bx + 3, H); x.fill();
    }
    if (o.flowers) for (let i = 0; i < 4; i++) {
      const fx = W * (0.2 + r() * 0.6), fy = H * (0.25 + r() * 0.3);
      for (let p = 0; p < 5; p++) { x.fillStyle = o.flowers; x.beginPath(); x.ellipse(fx + Math.cos(p * 1.256) * 4, fy + Math.sin(p * 1.256) * 4, 3.4, 2.2, p * 1.256, 0, TAU); x.fill(); }
      x.fillStyle = '#f2c94c'; x.beginPath(); x.arc(fx, fy, 2, 0, TAU); x.fill();
    }
    return c;
  }

  function mushrooms(o) {
    const W = o.w || 192, H = o.h || 160;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 11);
    const n = o.count || 5;
    const items = [];
    for (let i = 0; i < n; i++) items.push({ x: W * (0.2 + r() * 0.6), s: 14 + r() * 26, h: 20 + r() * 40 });
    items.sort((a, b) => a.s - b.s);
    if (o.glow) glow(x, W / 2, H * 0.6, W * 0.5, o.glow, 0.35);
    for (const m of items) {
      const by = H - 6 - r() * 10;
      x.fillStyle = '#e9dcc2';
      x.beginPath(); x.moveTo(m.x - m.s * 0.18, by); x.quadraticCurveTo(m.x - m.s * 0.1, by - m.h * 0.6, m.x - m.s * 0.12, by - m.h); x.lineTo(m.x + m.s * 0.12, by - m.h); x.quadraticCurveTo(m.x + m.s * 0.1, by - m.h * 0.6, m.x + m.s * 0.2, by); x.fill();
      x.fillStyle = 'rgba(90,60,40,0.35)'; x.fillRect(m.x + m.s * 0.02, by - m.h, m.s * 0.12, m.h);
      const cy = by - m.h;
      const g = x.createLinearGradient(m.x - m.s, cy - m.s * 0.6, m.x + m.s, cy);
      g.addColorStop(0, shade(o.cap, 0.25)); g.addColorStop(0.6, o.cap); g.addColorStop(1, shade(o.cap, -0.35));
      x.fillStyle = g;
      x.beginPath(); x.ellipse(m.x, cy, m.s * 0.75, m.s * 0.5, 0, Math.PI, TAU); x.quadraticCurveTo(m.x, cy + m.s * 0.12, m.x - m.s * 0.75, cy); x.fill();
      x.fillStyle = 'rgba(255,240,210,0.85)';
      for (let k = 0; k < 4; k++) { x.beginPath(); x.arc(m.x + (r() - 0.5) * m.s, cy - r() * m.s * 0.35, 1 + r() * m.s * 0.06, 0, TAU); x.fill(); }
      if (o.glow) glow(x, m.x, cy - m.s * 0.15, m.s * 0.9, o.glow, 0.25);
    }
    return c;
  }

  // ------------------------------------------------------------ stones and ruins
  function stoneShape(x, r, cx, by, w, h, pal, opt) {
    opt = opt || {};
    const pts = [];
    const n = 14;
    for (let i = 0; i < n; i++) {
      const t = i / n;
      const a = Math.PI + t * Math.PI;
      const jit = 1 + (r() - 0.5) * (opt.rough || 0.18);
      pts.push([cx + Math.cos(a) * w * 0.5 * jit, by + Math.sin(a) * h * jit * (opt.top || 1)]);
    }
    pts.push([cx + w * 0.52, by]); pts.push([cx - w * 0.52, by]);
    smoothClosed(x, pts);
    const g = x.createLinearGradient(cx - w / 2, by - h, cx + w / 2, by);
    g.addColorStop(0, pal[2]); g.addColorStop(0.45, pal[1]); g.addColorStop(1, pal[0]);
    x.fillStyle = g; x.fill();
    x.save(); x.clip();
    dabs(x, r, cx - w / 2, by - h, w, h, w * h / 90, [pal[0], pal[2], pal[1]], w * 0.03, 0.35);
    // cracks
    x.strokeStyle = rgba(shade(pal[0], -0.4), 0.6); x.lineWidth = 1.5;
    for (let k = 0; k < 4; k++) {
      let px = cx + (r() - 0.5) * w * 0.6, py = by - r() * h;
      x.beginPath(); x.moveTo(px, py);
      for (let s = 0; s < 4; s++) { px += (r() - 0.5) * w * 0.15; py += r() * h * 0.12; x.lineTo(px, py); }
      x.stroke();
    }
    if (opt.moss) {
      for (let k = 0; k < (opt.mossAmt || 1) * 120; k++) {
        const mx = cx + (r() - 0.5) * w, my = by - h * (0.55 + r() * 0.5);
        x.fillStyle = rgba(['#5f7d36', '#7d9a45', '#486a2c'][k % 3], 0.75);
        x.beginPath(); x.ellipse(mx, my, 3 + r() * 7, 2 + r() * 4, r(), 0, TAU); x.fill();
      }
    }
    // ground shadow
    const gs = x.createLinearGradient(0, by - h * 0.25, 0, by);
    gs.addColorStop(0, 'rgba(0,0,0,0)'); gs.addColorStop(1, 'rgba(8,12,8,0.55)');
    x.fillStyle = gs; x.fillRect(cx - w, by - h * 0.25, w * 2, h * 0.25);
    x.restore();
  }
  const STONE = ['#4a5150', '#7a8380', '#a9b1a8'];

  function boulder(o) {
    const W = o.w || 320, H = o.h || 224;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 13);
    stoneShape(x, r, W / 2, H - 6, W * 0.92, H * 0.88, o.pal || STONE, { moss: true, mossAmt: o.moss || 1, rough: 0.22 });
    return c;
  }

  function runestone(o) {
    const W = o.w || 256, H = o.h || 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 17);
    const by = H - 6;
    x.beginPath();
    x.moveTo(W * 0.18, by); x.lineTo(W * 0.14, H * 0.32); x.quadraticCurveTo(W * 0.2, H * 0.08, W * 0.52, H * 0.06);
    x.quadraticCurveTo(W * 0.84, H * 0.1, W * 0.86, H * 0.36); x.lineTo(W * 0.82, by); x.closePath();
    const g = x.createLinearGradient(0, 0, W, 0);
    g.addColorStop(0, STONE[2]); g.addColorStop(0.5, STONE[1]); g.addColorStop(1, STONE[0]);
    x.fillStyle = g; x.fill();
    x.save(); x.clip();
    dabs(x, r, 0, 0, W, H, 900, STONE, W * 0.02, 0.3);
    for (let k = 0; k < 160; k++) { x.fillStyle = rgba(['#5f7d36', '#7d9a45', '#486a2c'][k % 3], 0.8); x.beginPath(); x.ellipse(W * (0.1 + r() * 0.8), H * (r() < 0.6 ? 0.05 + r() * 0.2 : 0.75 + r() * 0.25), 3 + r() * 8, 2 + r() * 4, r(), 0, TAU); x.fill(); }
    const gs = x.createLinearGradient(0, H * 0.75, 0, H);
    gs.addColorStop(0, 'rgba(0,0,0,0)'); gs.addColorStop(1, 'rgba(8,12,8,0.6)');
    x.fillStyle = gs; x.fillRect(0, H * 0.75, W, H * 0.25);
    x.restore();
    // Carved rune (dark when dormant).
    drawRune(x, W / 2, H * 0.42, W * 0.22, o.rune || 0, 'rgba(30,34,32,0.85)', 5);
    return c;
  }

  // Rune glyphs: 0 moon (Deusa), 1 flame (Deus), 2 root, 3 star, 4 spiral.
  function drawRune(x, cx, cy, s, kind, color, lw) {
    x.save();
    x.strokeStyle = color; x.lineWidth = lw; x.lineCap = 'round'; x.lineJoin = 'round';
    x.beginPath();
    switch (kind) {
      case 0: // crescent moon with drop
        x.arc(cx, cy, s, Math.PI * 0.3, Math.PI * 1.7);
        x.moveTo(cx + s * 0.55, cy - s * 0.8);
        x.quadraticCurveTo(cx - s * 0.35, cy, cx + s * 0.55, cy + s * 0.8);
        break;
      case 1: // flame with three tongues
        x.moveTo(cx - s * 0.7, cy + s);
        x.quadraticCurveTo(cx - s * 1.0, cy, cx - s * 0.55, cy - s * 0.45);
        x.quadraticCurveTo(cx - s * 0.45, cy - s * 0.05, cx - s * 0.2, cy);
        x.quadraticCurveTo(cx - s * 0.3, cy - s * 0.7, cx, cy - s * 1.15);
        x.quadraticCurveTo(cx + s * 0.3, cy - s * 0.7, cx + s * 0.2, cy);
        x.quadraticCurveTo(cx + s * 0.45, cy - s * 0.05, cx + s * 0.55, cy - s * 0.45);
        x.quadraticCurveTo(cx + s * 1.0, cy, cx + s * 0.7, cy + s);
        x.closePath();
        x.moveTo(cx - s * 1.0, cy + s); x.lineTo(cx + s * 1.0, cy + s);
        break;
      case 2: // root
        x.moveTo(cx, cy - s); x.lineTo(cx, cy + s * 0.2);
        x.moveTo(cx, cy + s * 0.2); x.quadraticCurveTo(cx - s * 0.2, cy + s * 0.8, cx - s * 0.8, cy + s);
        x.moveTo(cx, cy + s * 0.2); x.quadraticCurveTo(cx + s * 0.2, cy + s * 0.8, cx + s * 0.8, cy + s);
        x.moveTo(cx, cy + s * 0.2); x.lineTo(cx, cy + s * 1.05);
        x.moveTo(cx - s * 0.5, cy - s * 0.5); x.lineTo(cx, cy - s * 0.2); x.lineTo(cx + s * 0.5, cy - s * 0.5);
        break;
      case 3: // eight-point star
        for (let i = 0; i < 4; i++) { const a = i * Math.PI / 4; x.moveTo(cx + Math.cos(a) * s, cy + Math.sin(a) * s); x.lineTo(cx - Math.cos(a) * s, cy - Math.sin(a) * s); }
        x.moveTo(cx + s * 0.35, cy); x.arc(cx, cy, s * 0.35, 0, TAU);
        break;
      case 4: // spiral
        for (let i = 0; i <= 60; i++) { const t = i / 60, a = t * TAU * 2.2, rr = s * t; const px = cx + Math.cos(a) * rr, py = cy + Math.sin(a) * rr; if (i === 0) x.moveTo(px, py); else x.lineTo(px, py); }
        break;
    }
    x.stroke();
    x.restore();
  }

  function runeGlow(o) {
    const W = o.w || 256, H = o.h || 256;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    glow(x, W / 2, H / 2, W * 0.5, o.color, 0.55);
    x.shadowColor = o.color; x.shadowBlur = 18;
    drawRune(x, W / 2, H / 2, W * 0.22, o.rune, o.core || '#fffbe8', 7);
    drawRune(x, W / 2, H / 2, W * 0.22, o.rune, o.color, 4);
    return c;
  }

  function pillar(o) {
    const W = o.w || 224, H = o.h || 512;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 19);
    const top = H * (o.broken ? 0.25 + r() * 0.2 : 0.08);
    const pw = W * 0.5;
    // base
    stoneShape(x, r, W / 2, H - 4, W * 0.9, H * 0.08, STONE, { top: 0.6, rough: 0.05 });
    x.beginPath();
    x.moveTo(W / 2 - pw / 2, H - H * 0.07);
    x.lineTo(W / 2 - pw / 2, top + 20);
    if (o.broken) { for (let i = 0; i <= 6; i++) x.lineTo(W / 2 - pw / 2 + pw * i / 6, top + (r() - 0.3) * 40); }
    else { x.lineTo(W / 2 - pw * 0.62, top + 20); x.lineTo(W / 2 - pw * 0.62, top); x.lineTo(W / 2 + pw * 0.62, top); x.lineTo(W / 2 + pw * 0.62, top + 20); }
    x.lineTo(W / 2 + pw / 2, top + 20);
    x.lineTo(W / 2 + pw / 2, H - H * 0.07);
    x.closePath();
    const g = x.createLinearGradient(W / 2 - pw / 2, 0, W / 2 + pw / 2, 0);
    g.addColorStop(0, STONE[2]); g.addColorStop(0.4, STONE[1]); g.addColorStop(1, STONE[0]);
    x.fillStyle = g; x.fill();
    x.save(); x.clip();
    // flutes
    for (let i = 1; i < 5; i++) { x.strokeStyle = 'rgba(40,46,44,0.35)'; x.lineWidth = 3; x.beginPath(); x.moveTo(W / 2 - pw / 2 + pw * i / 5, top); x.lineTo(W / 2 - pw / 2 + pw * i / 5, H); x.stroke(); }
    dabs(x, r, 0, 0, W, H, 700, STONE, W * 0.02, 0.28);
    // vines and moss
    for (let k = 0; k < 220; k++) { x.fillStyle = rgba(['#5f7d36', '#7d9a45', '#486a2c'][k % 3], 0.85); x.beginPath(); x.ellipse(W * (0.25 + r() * 0.5), top + r() * (H - top) * (r() < 0.5 ? 0.3 : 1), 2 + r() * 6, 1.5 + r() * 3, r(), 0, TAU); x.fill(); }
    x.restore();
    // hanging vine
    x.strokeStyle = '#4b6b2e'; x.lineWidth = 3;
    x.beginPath(); x.moveTo(W / 2 - pw / 2 + 6, top + 10); x.bezierCurveTo(W / 2 - pw / 2 - 10, top + H * 0.2, W / 2, top + H * 0.3, W / 2 - pw / 2 + 4, top + H * 0.45); x.stroke();
    for (let k = 0; k < 20; k++) { const t = k / 20; x.fillStyle = k % 2 ? '#6d8f3a' : '#56772f'; x.beginPath(); x.ellipse(W / 2 - pw / 2 + Math.sin(t * 6) * 10, top + 10 + t * H * 0.42, 6, 3, t * 5, 0, TAU); x.fill(); }
    return c;
  }

  function arch(o) {
    const W = o.w || 1024, H = o.h || 1024;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 23);
    const pw = W * 0.14, inner = W * 0.27, by = H - 6, springY = H * 0.46;
    const outer = inner + pw;
    const path = () => {
      x.beginPath();
      x.moveTo(W / 2 - outer, by); x.lineTo(W / 2 - outer, springY);
      x.arc(W / 2, springY, outer, Math.PI, 0);
      x.lineTo(W / 2 + outer, by); x.lineTo(W / 2 + inner, by); x.lineTo(W / 2 + inner, springY);
      x.arc(W / 2, springY, inner, 0, Math.PI, true);
      x.lineTo(W / 2 - inner, by); x.closePath();
    };
    path();
    const g = x.createLinearGradient(0, 0, W, H);
    g.addColorStop(0, STONE[2]); g.addColorStop(0.5, STONE[1]); g.addColorStop(1, STONE[0]);
    x.fillStyle = g; x.fill();
    x.save(); x.clip();
    dabs(x, r, 0, 0, W, H, 2600, STONE, W * 0.012, 0.3);
    // voussoir joints
    x.strokeStyle = 'rgba(35,40,38,0.55)'; x.lineWidth = 3;
    for (let i = 0; i <= 12; i++) { const a = Math.PI + i / 12 * Math.PI; x.beginPath(); x.moveTo(W / 2 + Math.cos(a) * inner, springY + Math.sin(a) * inner); x.lineTo(W / 2 + Math.cos(a) * outer, springY + Math.sin(a) * outer); x.stroke(); }
    for (let yy = springY; yy < by; yy += H * 0.08) { x.beginPath(); x.moveTo(W / 2 - outer, yy); x.lineTo(W / 2 - inner, yy); x.moveTo(W / 2 + inner, yy); x.lineTo(W / 2 + outer, yy); x.stroke(); }
    // moss
    for (let k = 0; k < 900; k++) { const a = Math.PI + r() * Math.PI; const rr = inner + r() * pw; x.fillStyle = rgba(['#5f7d36', '#7d9a45', '#486a2c'][k % 3], 0.85); x.beginPath(); x.ellipse(W / 2 + Math.cos(a) * rr, springY + Math.sin(a) * rr - r() * 10, 3 + r() * 9, 2 + r() * 4, r(), 0, TAU); x.fill(); }
    const gs = x.createLinearGradient(0, by - H * 0.15, 0, by);
    gs.addColorStop(0, 'rgba(0,0,0,0)'); gs.addColorStop(1, 'rgba(8,12,8,0.6)');
    x.fillStyle = gs; x.fillRect(0, by - H * 0.15, W, H * 0.15);
    x.restore();
    // keystone runes: moon and flame side by side
    drawRune(x, W / 2 - outer + pw / 2, springY + H * 0.12, pw * 0.25, 0, 'rgba(28,32,30,0.8)', 5);
    drawRune(x, W / 2 + outer - pw / 2, springY + H * 0.12, pw * 0.25, 1, 'rgba(28,32,30,0.8)', 5);
    drawRune(x, W / 2, springY - outer + pw * 0.5, pw * 0.22, 3, 'rgba(28,32,30,0.8)', 5);
    // hanging vines
    for (let v = 0; v < 7; v++) {
      const a = Math.PI + (0.12 + r() * 0.76) * Math.PI;
      const sx = W / 2 + Math.cos(a) * inner, sy = springY + Math.sin(a) * inner;
      const len = H * (0.08 + r() * 0.22);
      for (let k = 0; k < len / 8; k++) { x.fillStyle = k % 2 ? '#6d8f3a' : '#4f7030'; x.beginPath(); x.ellipse(sx + Math.sin(k * 0.6) * 5, sy + k * 8, 6, 3.5, k, 0, TAU); x.fill(); }
    }
    return c;
  }

  function wallRuin(o) {
    const W = o.w || 512, H = o.h || 288;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 29);
    const rows = 5, bh = (H - 10) / rows;
    for (let row = 0; row < rows; row++) {
      const y = H - 6 - (row + 1) * bh;
      const maxW = W * (1 - row * 0.12 - r() * 0.2);
      let xx = (W - maxW) / 2 + (r() - 0.5) * 30;
      while (xx < (W + maxW) / 2) {
        const bw = 50 + r() * 60;
        x.save();
        x.beginPath(); x.rect(xx + 2, y + 2, Math.min(bw, (W + maxW) / 2 - xx) - 4, bh - 4);
        const g = x.createLinearGradient(xx, y, xx + bw, y + bh);
        g.addColorStop(0, STONE[2]); g.addColorStop(1, STONE[0]);
        x.fillStyle = g; x.fill(); x.clip();
        dabs(x, r, xx, y, bw, bh, 30, STONE, 5, 0.3);
        if (r() < 0.5) for (let k = 0; k < 12; k++) { x.fillStyle = rgba('#5f7d36', 0.8); x.beginPath(); x.ellipse(xx + r() * bw, y + r() * bh * 0.4, 3 + r() * 6, 2 + r() * 3, 0, 0, TAU); x.fill(); }
        x.restore();
        xx += bw;
      }
    }
    return c;
  }

  function lantern(o) {
    // Stone lantern totem with an empty cavity; the flame is a separate glow.
    const W = o.w || 160, H = o.h || 320;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 31);
    const by = H - 4;
    const block = (cx, cy, w, h) => {
      x.beginPath(); x.rect(cx - w / 2, cy - h, w, h);
      const g = x.createLinearGradient(cx - w / 2, 0, cx + w / 2, 0);
      g.addColorStop(0, STONE[2]); g.addColorStop(0.5, STONE[1]); g.addColorStop(1, STONE[0]);
      x.fillStyle = g; x.fill();
      x.save(); x.clip(); dabs(x, r, cx - w / 2, cy - h, w, h, w * h / 40, STONE, 3, 0.3); x.restore();
    };
    block(W / 2, by, W * 0.7, H * 0.08);
    block(W / 2, by - H * 0.08, W * 0.3, H * 0.4);
    block(W / 2, by - H * 0.48, W * 0.62, H * 0.06);
    block(W / 2, by - H * 0.54, W * 0.52, H * 0.22);
    // cavity
    x.fillStyle = '#1b1f1c'; x.fillRect(W / 2 - W * 0.15, by - H * 0.73, W * 0.3, H * 0.15);
    // roof
    x.beginPath(); x.moveTo(W * 0.08, by - H * 0.76); x.quadraticCurveTo(W / 2, by - H * 0.86, W * 0.92, by - H * 0.76); x.lineTo(W / 2, by - H * 0.97); x.closePath();
    const g = x.createLinearGradient(0, 0, W, 0); g.addColorStop(0, STONE[2]); g.addColorStop(1, STONE[0]); x.fillStyle = g; x.fill();
    for (let k = 0; k < 60; k++) { x.fillStyle = rgba(['#5f7d36', '#7d9a45'][k % 2], 0.85); x.beginPath(); x.ellipse(W * (0.15 + r() * 0.7), by - H * (0.78 + r() * 0.12), 2 + r() * 5, 1.5 + r() * 2.5, 0, 0, TAU); x.fill(); }
    return c;
  }

  function pedestal(o) {
    const W = o.w || 256, H = o.h || 288;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 37);
    stoneShape(x, r, W / 2, H - 4, W * 0.86, H * 0.1, STONE, { top: 0.7, rough: 0.05 });
    x.beginPath(); x.moveTo(W * 0.3, H - H * 0.08); x.lineTo(W * 0.34, H * 0.42); x.lineTo(W * 0.66, H * 0.42); x.lineTo(W * 0.7, H - H * 0.08); x.closePath();
    const g = x.createLinearGradient(W * 0.3, 0, W * 0.7, 0); g.addColorStop(0, STONE[2]); g.addColorStop(1, STONE[0]);
    x.fillStyle = g; x.fill();
    x.save(); x.clip(); dabs(x, r, 0, 0, W, H, 300, STONE, 4, 0.3); x.restore();
    // bowl
    x.beginPath(); x.ellipse(W / 2, H * 0.4, W * 0.32, H * 0.07, 0, 0, TAU);
    x.fillStyle = STONE[1]; x.fill();
    x.beginPath(); x.ellipse(W / 2, H * 0.39, W * 0.26, H * 0.045, 0, 0, TAU);
    x.fillStyle = '#2b302d'; x.fill();
    drawRune(x, W / 2, H * 0.62, W * 0.1, o.rune, 'rgba(28,32,30,0.85)', 4);
    for (let k = 0; k < 70; k++) { x.fillStyle = rgba(['#5f7d36', '#7d9a45'][k % 2], 0.85); x.beginPath(); x.ellipse(W * (0.3 + r() * 0.4), H * (0.85 + r() * 0.12), 2 + r() * 6, 1.5 + r() * 2.5, 0, 0, TAU); x.fill(); }
    return c;
  }

  function log(o) {
    const W = o.w || 512, H = o.h || 192;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 41);
    const by = H - 8, rad = H * 0.32;
    x.beginPath(); x.moveTo(W * 0.1, by - rad * 2); x.lineTo(W * 0.88, by - rad * 1.8); x.lineTo(W * 0.88, by); x.lineTo(W * 0.1, by); x.closePath();
    const g = x.createLinearGradient(0, by - rad * 2, 0, by);
    g.addColorStop(0, '#8a6b4f'); g.addColorStop(0.45, '#5b4231'); g.addColorStop(1, '#2e2018');
    x.fillStyle = g; x.fill();
    x.save(); x.clip();
    for (let i = 0; i < 160; i++) { const yy = by - r() * rad * 2; x.strokeStyle = rgba(r() < 0.5 ? '#2a1d14' : '#a0805e', 0.35); x.lineWidth = 1 + r() * 2; x.beginPath(); x.moveTo(W * 0.1 + r() * W * 0.7, yy); x.lineTo(W * 0.1 + r() * W * 0.8, yy + (r() - 0.5) * 4); x.stroke(); }
    for (let k = 0; k < 260; k++) { x.fillStyle = rgba(['#5f7d36', '#7d9a45', '#486a2c'][k % 3], 0.85); x.beginPath(); x.ellipse(W * (0.1 + r() * 0.78), by - rad * (1.5 + r() * 0.5), 3 + r() * 7, 2 + r() * 3, 0, 0, TAU); x.fill(); }
    x.restore();
    // end grain
    x.beginPath(); x.ellipse(W * 0.88, by - rad * 0.9, rad * 0.5, rad * 0.92, 0, 0, TAU);
    x.fillStyle = '#b08d64'; x.fill();
    x.strokeStyle = '#7a5b3e'; x.lineWidth = 2;
    for (let k = 1; k < 5; k++) { x.beginPath(); x.ellipse(W * 0.88, by - rad * 0.9, rad * 0.5 * k / 5, rad * 0.92 * k / 5, 0, 0, TAU); x.stroke(); }
    if (o.mush) { const m = mushrooms({ w: 160, h: 120, cap: '#d9792e', seed: 77, count: 4 }); x.drawImage(m, W * 0.35, by - rad * 2 - 90, 160, 120); }
    return c;
  }

  // Ancient sanctuary tree: huge gnarled trunk with a hollow and glowing roots.
  function ancientTree(o) {
    const c = tree({ w: 1024, h: 1280, seed: o.seed || 101, trunk: 0.46, girth: 0.17, canopyY: 0.25, canopyH: 0.22, clusters: 60, branches: 9, moss: true,
      leaves: ['#2c3b2a', '#c76f2c', '#e09a3d', '#7f8f3a', '#f6cf7a', '#ffe7a8'], bark: ['#31261f', '#56443a', '#8e7663'] });
    const x = c.getContext('2d');
    // hollow
    x.save();
    x.beginPath(); x.ellipse(512, 1080, 70, 110, 0, 0, TAU);
    const g = x.createRadialGradient(512, 1100, 10, 512, 1080, 110);
    g.addColorStop(0, '#0b0d0b'); g.addColorStop(1, '#2a211b');
    x.fillStyle = g; x.fill();
    x.strokeStyle = '#6e5848'; x.lineWidth = 8; x.stroke();
    x.restore();
    return c;
  }

  // ------------------------------------------------------------ tiling ground
  function groundTile(o) {
    const W = o.size || 512, H = W;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 51);
    const n = noise2(o.seed || 51);
    const img = x.createImageData(W, H);
    const A = Paint.hex(o.c0), B = Paint.hex(o.c1), Cc = Paint.hex(o.c2);
    for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
      const v = tileNoise(n, xx / W * 6, yy / H * 6, 6, 6, 4);
      const v2 = tileNoise(n, xx / W * 24 + 50, yy / H * 24 + 50, 24, 24, 2);
      const t = Math.min(1, Math.max(0, (v - 0.3) * 2.2));
      const k = v2 * 0.25;
      const i = (yy * W + xx) * 4;
      for (let ch = 0; ch < 3; ch++) {
        const base = t < 0.5 ? A[ch] + (B[ch] - A[ch]) * t * 2 : B[ch] + (Cc[ch] - B[ch]) * (t - 0.5) * 2;
        img.data[i + ch] = Math.max(0, Math.min(255, base * (0.88 + k)));
      }
      img.data[i + 3] = 255;
    }
    x.putImageData(img, 0, 0);
    // Wrapped brush dabs (grass blades / pebbles).
    const draw = (fn) => { for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) { x.save(); x.translate(ox, oy); fn(); x.restore(); } };
    for (let i = 0; i < (o.blades || 0); i++) {
      const px = r() * W, py = r() * H, l = 6 + r() * 12, a = -Math.PI / 2 + (r() - 0.5) * 1.2;
      const col = o.bladeCols[Math.floor(r() * o.bladeCols.length)];
      draw(() => { x.strokeStyle = rgba(col, 0.55); x.lineWidth = 1.6; x.beginPath(); x.moveTo(px, py); x.lineTo(px + Math.cos(a) * l, py + Math.sin(a) * l); x.stroke(); });
    }
    for (let i = 0; i < (o.pebbles || 0); i++) {
      const px = r() * W, py = r() * H, s = 2 + r() * 5;
      draw(() => { x.fillStyle = rgba(o.pebbleCol, 0.7); x.beginPath(); x.ellipse(px, py, s, s * 0.7, r(), 0, TAU); x.fill(); x.fillStyle = 'rgba(255,255,255,0.15)'; x.beginPath(); x.ellipse(px - s * 0.3, py - s * 0.3, s * 0.4, s * 0.25, 0, 0, TAU); x.fill(); });
    }
    for (let i = 0; i < (o.leafCount || 0); i++) {
      const px = r() * W, py = r() * H, s = 4 + r() * 5, a = r() * TAU;
      const col = o.leafCols[Math.floor(r() * o.leafCols.length)];
      draw(() => { x.fillStyle = rgba(col, 0.85); x.beginPath(); x.ellipse(px, py, s, s * 0.45, a, 0, TAU); x.fill(); });
    }
    return c;
  }

  // Flagstone path tile.
  function pathTile(o) {
    const W = o.size || 512, H = W;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 61);
    x.fillStyle = '#4a4232'; x.fillRect(0, 0, W, H);
    dabs(x, r, 0, 0, W, H, 1200, ['#3a3426', '#5a5038', '#4d5a33'], 6, 0.5);
    // Jittered grid of stones (tile-safe: wraps by drawing copies).
    const cells = 5, cs = W / cells;
    for (let gy = 0; gy < cells; gy++) for (let gx = 0; gx < cells; gx++) {
      const cx = (gx + 0.5 + (r() - 0.5) * 0.35 + (gy % 2) * 0.5) * cs, cy = (gy + 0.5 + (r() - 0.5) * 0.3) * cs;
      const pts = [];
      const nn = 7, rad = cs * (0.38 + r() * 0.08);
      for (let k = 0; k < nn; k++) { const a = k / nn * TAU + r() * 0.3; pts.push([Math.cos(a) * rad * (0.8 + r() * 0.3), Math.sin(a) * rad * (0.75 + r() * 0.3)]); }
      const tone = r();
      for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) {
        x.save(); x.translate(cx + ox, cy + oy);
        Paint.smoothClosed(x, pts);
        const g = x.createLinearGradient(-rad, -rad, rad, rad);
        g.addColorStop(0, mix('#a6a491', '#8b8f80', tone)); g.addColorStop(1, mix('#6d6c5d', '#5b6156', tone));
        x.fillStyle = g; x.fill();
        x.strokeStyle = 'rgba(30,28,20,0.6)'; x.lineWidth = 3; x.stroke();
        x.clip();
        dabs(x, r, -rad, -rad, rad * 2, rad * 2, 30, ['#9b9a88', '#6f7064', '#7c8a5a'], 4, 0.35);
        x.restore();
      }
    }
    // moss in gaps
    for (let i = 0; i < 500; i++) { const px = r() * W, py = r() * H; x.fillStyle = rgba(['#55702f', '#6c8a3a'][i % 2], 0.5); x.beginPath(); x.ellipse(px, py, 2 + r() * 4, 1.5 + r() * 2, 0, 0, TAU); x.fill(); }
    return c;
  }

  // ------------------------------------------------------------ effects
  function softDot(o) {
    const S = o.size || 128;
    const c = makeCanvas(S, S), x = c.getContext('2d');
    const g = x.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(o.core || 0.2, 'rgba(255,255,255,0.65)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, S, S);
    return c;
  }
  function sparkle(o) {
    const S = o.size || 128;
    const c = makeCanvas(S, S), x = c.getContext('2d');
    const g = x.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S * 0.2);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, S, S);
    x.fillStyle = 'rgba(255,255,255,0.95)';
    for (const [a, l, w] of [[0, 0.48, 0.035], [Math.PI / 2, 0.48, 0.035], [Math.PI / 4, 0.26, 0.025], [-Math.PI / 4, 0.26, 0.025]]) {
      x.save(); x.translate(S / 2, S / 2); x.rotate(a);
      x.beginPath(); x.moveTo(-S * l, 0); x.quadraticCurveTo(0, -S * w, S * l, 0); x.quadraticCurveTo(0, S * w, -S * l, 0); x.fill();
      x.restore();
    }
    return c;
  }
  function leafParticle(o) {
    const S = 64; const c = makeCanvas(S, S), x = c.getContext('2d');
    x.fillStyle = o.color;
    x.beginPath(); x.moveTo(8, 32); x.quadraticCurveTo(32, 6, 56, 32); x.quadraticCurveTo(32, 58, 8, 32); x.fill();
    x.strokeStyle = shade(o.color, -0.35); x.lineWidth = 2; x.beginPath(); x.moveTo(8, 32); x.lineTo(56, 32); x.stroke();
    return c;
  }
  function lightShaft() {
    const W = 128, H = 512; const c = makeCanvas(W, H), x = c.getContext('2d');
    const g = x.createLinearGradient(0, 0, W, 0);
    g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,1)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, W, H);
    x.globalCompositeOperation = 'destination-in';
    const v = x.createLinearGradient(0, 0, 0, H);
    v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(0.15, 'rgba(0,0,0,1)'); v.addColorStop(0.7, 'rgba(0,0,0,0.7)'); v.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = v; x.fillRect(0, 0, W, H);
    return c;
  }
  function blobShadow() {
    const S = 128; const c = makeCanvas(S, S), x = c.getContext('2d');
    const g = x.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
    g.addColorStop(0, 'rgba(0,0,0,0.75)'); g.addColorStop(0.55, 'rgba(0,0,0,0.4)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g; x.fillRect(0, 0, S, S);
    return c;
  }
  function magicCircle(o) {
    const S = o.size || 512; const c = makeCanvas(S, S), x = c.getContext('2d');
    x.translate(S / 2, S / 2);
    x.strokeStyle = 'rgba(255,255,255,0.95)'; x.lineWidth = 4;
    x.beginPath(); x.arc(0, 0, S * 0.46, 0, TAU); x.stroke();
    x.lineWidth = 2; x.beginPath(); x.arc(0, 0, S * 0.41, 0, TAU); x.stroke();
    x.beginPath(); x.arc(0, 0, S * 0.25, 0, TAU); x.stroke();
    for (let i = 0; i < 8; i++) {
      const a = i / 8 * TAU;
      x.save(); x.rotate(a); x.translate(0, -S * 0.435);
      drawRune(x, 0, 0, S * 0.022, i % 5, 'rgba(255,255,255,0.95)', 2.5);
      x.restore();
    }
    // hexagram of two triangles: the Goddess and the God
    for (const off of [0, Math.PI]) {
      x.beginPath();
      for (let k = 0; k <= 3; k++) { const a = off - Math.PI / 2 + k * TAU / 3; const px = Math.cos(a) * S * 0.41, py = Math.sin(a) * S * 0.41; if (k === 0) x.moveTo(px, py); else x.lineTo(px, py); }
      x.stroke();
    }
    return c;
  }

  // Shadow wisp enemy frames (4 frames in a row).
  function shade_(o) {
    const F = 4, W = 192, H = 224;
    const c = makeCanvas(W * F, H), x = c.getContext('2d');
    for (let f = 0; f < F; f++) {
      const r = rng(300 + f);
      x.save(); x.translate(f * W, 0);
      const t = f / F * TAU;
      // smoky body
      for (let k = 0; k < 70; k++) {
        const a = r() * TAU, d = Math.pow(r(), 0.7);
        const px = W / 2 + Math.cos(a) * 46 * d + Math.sin(t + k) * 4;
        const py = H * 0.48 + Math.sin(a) * 50 * d + (d * 30) * Math.max(0, Math.sin(a)) + Math.cos(t + k * 0.5) * 3;
        const s = 18 + r() * 22 * (1 - d * 0.5);
        const g = x.createRadialGradient(px, py, 0, px, py, s);
        g.addColorStop(0, 'rgba(18,10,30,0.55)'); g.addColorStop(1, 'rgba(18,10,30,0)');
        x.fillStyle = g; x.beginPath(); x.arc(px, py, s, 0, TAU); x.fill();
      }
      // tendrils
      for (let k = 0; k < 6; k++) {
        const sx = W / 2 + (k - 2.5) * 12;
        x.strokeStyle = 'rgba(25,12,40,0.6)'; x.lineWidth = 7 - k * 0.5; x.lineCap = 'round';
        x.beginPath(); x.moveTo(sx, H * 0.62);
        x.bezierCurveTo(sx + Math.sin(t + k) * 18, H * 0.75, sx - Math.sin(t + k * 1.3) * 22, H * 0.85, sx + Math.sin(t * 2 + k) * 14, H * 0.96);
        x.stroke();
      }
      // eyes
      for (const s of [-1, 1]) {
        const ex = W / 2 + s * 15, ey = H * 0.43;
        glow(x, ex, ey, 22, '#b07cff', 0.7);
        x.fillStyle = '#f2e6ff';
        x.beginPath(); x.ellipse(ex, ey, 6, 3.4 + (f === 2 ? -2 : 0), s * -0.35, 0, TAU); x.fill();
      }
      x.restore();
    }
    return c;
  }

  // ------------------------------------------------------------ UI art
  function emblem() {
    const S = 256; const c = makeCanvas(S, S), x = c.getContext('2d');
    x.translate(S / 2, S / 2);
    // diamond frame
    x.rotate(Math.PI / 4);
    x.fillStyle = '#16231b'; x.strokeStyle = '#c9a964'; x.lineWidth = 7;
    x.beginPath(); x.rect(-78, -78, 156, 156); x.fill(); x.stroke();
    x.lineWidth = 2.5; x.strokeStyle = 'rgba(201,169,100,0.6)'; x.beginPath(); x.rect(-64, -64, 128, 128); x.stroke();
    x.rotate(-Math.PI / 4);
    // leaf
    x.fillStyle = '#e7d7a6';
    x.beginPath(); x.moveTo(0, -62); x.bezierCurveTo(42, -30, 40, 28, 0, 62); x.bezierCurveTo(-40, 28, -42, -30, 0, -62); x.fill();
    x.strokeStyle = '#16231b'; x.lineWidth = 4;
    x.beginPath(); x.moveTo(0, -50); x.lineTo(0, 58); x.stroke();
    for (let i = 0; i < 4; i++) { const y = -30 + i * 20; x.beginPath(); x.moveTo(0, y + 10); x.lineTo(-22 + i * 3, y - 6); x.moveTo(0, y + 10); x.lineTo(22 - i * 3, y - 6); x.stroke(); }
    return c;
  }

  // Thorny roots that seal a path; faint green veins hint they can be awakened.
  function rootsBarrier(o) {
    const W = o.w || 384, H = o.h || 448;
    const c = makeCanvas(W, H), x = c.getContext('2d');
    const r = rng(o.seed || 71);
    const roots = [];
    for (let i = 0; i < 9; i++) {
      const sx = W * (0.1 + r() * 0.8), ex = W * (0.1 + r() * 0.8);
      const top = H * (0.08 + r() * 0.35);
      roots.push({ pts: curve([sx, H - 4], [lerp(sx, ex, 0.5) + (r() - 0.5) * W * 0.6, top - H * 0.15], [ex, H - 4 - r() * H * 0.3], 26), w: 10 + r() * 16 });
    }
    function lerp(a, b, t) { return a + (b - a) * t; }
    for (const rt of roots) {
      const poly = limbPoly(rt.pts, rt.w, rt.w * 0.35);
      polyPath(x, poly);
      const g = x.createLinearGradient(0, 0, W, H);
      g.addColorStop(0, '#6b5240'); g.addColorStop(0.5, '#45332a'); g.addColorStop(1, '#2a1f19');
      x.fillStyle = g; x.fill();
      x.strokeStyle = 'rgba(15,10,8,0.8)'; x.lineWidth = 2; x.stroke();
      // thorns
      for (let k = 2; k < rt.pts.length - 2; k += 2) {
        const p = rt.pts[k], q = rt.pts[k + 1];
        const dx = q[0] - p[0], dy = q[1] - p[1], l = Math.hypot(dx, dy) || 1;
        const s = r() < 0.5 ? 1 : -1, w = rt.w * (1 - k / rt.pts.length * 0.6) * 0.5;
        x.fillStyle = '#2b1f18';
        x.beginPath(); x.moveTo(p[0] - dy / l * w * s, p[1] + dx / l * w * s); x.lineTo(p[0] - dy / l * (w + 9) * s + dx / l * 4, p[1] + dx / l * (w + 9) * s + dy / l * 4); x.lineTo(p[0] + dx / l * 6 - dy / l * w * s, p[1] + dy / l * 6 + dx / l * w * s); x.fill();
      }
      // glowing vein
      x.strokeStyle = 'rgba(140,255,170,0.55)'; x.lineWidth = 2.2;
      x.beginPath(); x.moveTo(rt.pts[2][0], rt.pts[2][1]);
      for (let k = 3; k < rt.pts.length - 3; k++) x.lineTo(rt.pts[k][0] + Math.sin(k) * 2, rt.pts[k][1]);
      x.stroke();
    }
    for (let k = 0; k < 120; k++) { x.fillStyle = rgba(['#4b6b2e', '#6d8f3a'][k % 2], 0.85); x.beginPath(); x.ellipse(W * (0.1 + r() * 0.8), H * (0.3 + r() * 0.7), 3 + r() * 5, 2 + r() * 2, r() * 3, 0, TAU); x.fill(); }
    return c;
  }

  global.Env = { rootsBarrier, tree, farTree, bush, fern, grassTuft, mushrooms, boulder, runestone, runeGlow, pillar, arch, wallRuin, lantern, pedestal, log, ancientTree, groundTile, pathTile, softDot, sparkle, leafParticle, lightShaft, blobShadow, magicCircle, shadeWisp: shade_, emblem, drawRune };
})(window);
