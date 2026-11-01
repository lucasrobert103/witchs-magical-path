// Shared painting helpers for the Asterion art pipeline (runs inside Chromium).
// Everything is deterministic: the same seed always produces the same pixels.
(function (global) {
  'use strict';

  function rng(seed) {
    let s = (seed >>> 0) || 1;
    return function () {
      s ^= s << 13; s >>>= 0;
      s ^= s >>> 17;
      s ^= s << 5; s >>>= 0;
      return (s >>> 0) / 4294967296;
    };
  }

  function hex(c) {
    if (typeof c !== 'string') return c;
    const h = c.replace('#', '');
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  }
  function rgba(c, a) {
    const v = hex(c);
    return `rgba(${v[0] | 0},${v[1] | 0},${v[2] | 0},${a === undefined ? 1 : a})`;
  }
  function mix(a, b, t) {
    const x = hex(a), y = hex(b);
    return '#' + [0, 1, 2].map(i => Math.round(x[i] + (y[i] - x[i]) * t).toString(16).padStart(2, '0')).join('');
  }
  function shade(c, k) { return k < 0 ? mix(c, '#000000', -k) : mix(c, '#ffffff', k); }

  function makeCanvas(w, h) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    return c;
  }

  // Value noise for painterly texture.
  function noise2(seed) {
    const r = rng(seed);
    const N = 256, perm = new Uint8Array(N * 2), grad = new Float32Array(N);
    for (let i = 0; i < N; i++) { perm[i] = i; grad[i] = r(); }
    for (let i = N - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); const t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
    for (let i = 0; i < N; i++) perm[N + i] = perm[i];
    const sm = t => t * t * (3 - 2 * t);
    function v(x, y) {
      const xi = Math.floor(x), yi = Math.floor(y);
      const xf = x - xi, yf = y - yi;
      const a = grad[perm[(xi & 255) + perm[yi & 255]]];
      const b = grad[perm[((xi + 1) & 255) + perm[yi & 255]]];
      const c = grad[perm[(xi & 255) + perm[(yi + 1) & 255]]];
      const d = grad[perm[((xi + 1) & 255) + perm[(yi + 1) & 255]]];
      const u = sm(xf), w = sm(yf);
      return a + (b - a) * u + (c - a) * w + (a - b - c + d) * u * w;
    }
    return function (x, y, oct) {
      let s = 0, amp = 1, tot = 0, f = 1;
      for (let o = 0; o < (oct || 4); o++) { s += v(x * f, y * f) * amp; tot += amp; amp *= 0.5; f *= 2; }
      return s / tot;
    };
  }

  // Tileable noise: samples a torus by blending four shifted lookups.
  function tileNoise(n, x, y, w, h, oct) {
    const u = x / w, v = y / h;
    const a = n(x, y, oct), b = n(x - w, y, oct), c = n(x, y - h, oct), d = n(x - w, y - h, oct);
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
  }

  // Organic blob path around a center.
  function blobPath(ctx, cx, cy, rx, ry, r, wob, steps) {
    steps = steps || 18;
    const pts = [];
    const ph = r() * 10;
    for (let i = 0; i < steps; i++) {
      const a = i / steps * Math.PI * 2;
      const k = 1 + (r() - 0.5) * wob + Math.sin(a * 3 + ph) * wob * 0.3;
      pts.push([cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]);
    }
    smoothClosed(ctx, pts);
  }

  function smoothClosed(ctx, pts) {
    const n = pts.length;
    ctx.beginPath();
    const m0 = [(pts[n - 1][0] + pts[0][0]) / 2, (pts[n - 1][1] + pts[0][1]) / 2];
    ctx.moveTo(m0[0], m0[1]);
    for (let i = 0; i < n; i++) {
      const p = pts[i], q = pts[(i + 1) % n];
      ctx.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2);
    }
    ctx.closePath();
  }

  function smoothOpen(ctx, pts) {
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length - 1; i++) {
      const p = pts[i], q = pts[i + 1];
      ctx.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2);
    }
    const l = pts[pts.length - 1];
    ctx.lineTo(l[0], l[1]);
  }

  function convexHull(points) {
    const p = points.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    if (p.length < 3) return p;
    const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
    const lo = [], up = [];
    for (const q of p) { while (lo.length >= 2 && cross(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) lo.pop(); lo.push(q); }
    for (let i = p.length - 1; i >= 0; i--) { const q = p[i]; while (up.length >= 2 && cross(up[up.length - 2], up[up.length - 1], q) <= 0) up.pop(); up.push(q); }
    up.pop(); lo.pop();
    return lo.concat(up);
  }

  // Soft radial glow sprite.
  function glow(ctx, x, y, r, color, a) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, rgba(color, a));
    g.addColorStop(0.4, rgba(color, a * 0.45));
    g.addColorStop(1, rgba(color, 0));
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  }

  // Paint dabs inside the current clip to give a brushed texture.
  function dabs(ctx, r, x0, y0, w, h, count, colors, size, alpha) {
    for (let i = 0; i < count; i++) {
      const x = x0 + r() * w, y = y0 + r() * h;
      const s = size * (0.5 + r());
      ctx.fillStyle = rgba(colors[Math.floor(r() * colors.length)], alpha * (0.5 + r() * 0.5));
      ctx.beginPath();
      ctx.ellipse(x, y, s, s * (0.4 + r() * 0.5), r() * Math.PI, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  global.Paint = { rng, hex, rgba, mix, shade, makeCanvas, noise2, tileNoise, blobPath, smoothClosed, smoothOpen, convexHull, glow, dabs };
})(window);
