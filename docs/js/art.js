// Programmatic block art on Canvas 2D — mirrors BlockArt.swift.
// Every design is drawn relative to its rect; no image assets.

import { designForId, css, CRACKED } from './designs.js';

function roundRectPath(ctx, x, y, w, h, r) {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

// Draw one block. (x, y) is the top-left, (w, h) the size.
export function drawBlock(ctx, x, y, w, h, designID, isCracked = false) {
  const design = designForId(isCracked ? CRACKED.id : designID);
  const base = design.base;
  const accent = design.accent;
  const rect = { x, y, w, h, minX: x, minY: y, maxX: x + w, maxY: y + h,
                 midX: x + w / 2, midY: y + h / 2 };

  ctx.save();
  roundRectPath(ctx, x, y, w, h, 2.5);
  ctx.clip();
  ctx.fillStyle = css(base);
  ctx.fillRect(x, y, w, h);

  const draw = PATTERNS[design.id];
  if (draw) draw(ctx, rect, accent);

  // Shared subtle 3D edge treatment.
  if (design.id !== 'cracked') {
    strokeLine(ctx, rect.minX, rect.minY + 0.5, rect.maxX, rect.minY + 0.5, 'rgba(255,255,255,0.30)', 1);
    strokeLine(ctx, rect.minX, rect.maxY - 0.5, rect.maxX, rect.maxY - 0.5, 'rgba(0,0,0,0.18)', 1);
  }
  ctx.restore();

  // Crowns/bushes intentionally rise above the top edge: drawn unclipped.
  if (design.id === 'garden') drawGardenBushes(ctx, rect, accent);
  if (design.id === 'blossom') drawBlossomCrowns(ctx, rect);

  ctx.save();
  roundRectPath(ctx, x, y, w, h, 2.5);
  ctx.strokeStyle = 'rgba(0,0,0,0.10)';
  ctx.lineWidth = 0.5;
  ctx.stroke();
  ctx.restore();
}

// --- helpers -------------------------------------------------------------

function strokeLine(ctx, x1, y1, x2, y2, style, width) {
  ctx.strokeStyle = style;
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();
}

function fillEllipse(ctx, x, y, w, h, style) {
  ctx.fillStyle = style;
  ctx.beginPath();
  ctx.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2);
  ctx.fill();
}

function strokeEllipse(ctx, x, y, w, h, style, width) {
  ctx.strokeStyle = style;
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2);
  ctx.stroke();
}

// --- per-design patterns -------------------------------------------------

const PATTERNS = {
  brick(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.8);
    ctx.lineWidth = 1;
    ctx.beginPath();
    const rowH = r.h / 3;
    for (let i = 1; i < 3; i++) {
      const y = r.minY + rowH * i;
      ctx.moveTo(r.minX, y);
      ctx.lineTo(r.maxX, y);
    }
    for (let course = 0; course < 3; course++) {
      const y0 = r.minY + rowH * course;
      const offset = course % 2 === 0 ? r.w / 2 : r.w / 4;
      for (let x = r.minX + offset; x < r.maxX; x += r.w / 2) {
        ctx.moveTo(x, y0);
        ctx.lineTo(x, y0 + rowH);
      }
    }
    ctx.stroke();
  },

  glass(ctx, r, accent) {
    const ix = r.minX + r.w * 0.12, iy = r.minY + r.h * 0.14;
    const iw = r.w * 0.76, ih = r.h * 0.72;
    const cols = 3, rows = 2;
    const cw = iw / cols, ch = ih / rows;
    ctx.fillStyle = css(accent, 0.85);
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        ctx.fillRect(ix + col * cw + 1, iy + row * ch + 1, cw - 2, ch - 2);
      }
    }
  },

  wood(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.7);
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 1; i < 3; i++) {
      const y = r.minY + (r.h / 3) * i;
      ctx.moveTo(r.minX, y);
      ctx.lineTo(r.maxX, y);
    }
    ctx.stroke();
    fillEllipse(ctx, r.minX + r.w * 0.25, r.minY + r.h * 0.10, r.w * 0.10, r.h * 0.12, css(accent, 0.8));
    fillEllipse(ctx, r.minX + r.w * 0.62, r.minY + r.h * 0.72, r.w * 0.10, r.h * 0.12, css(accent, 0.8));
  },

  garden(ctx, r, accent) {
    const band = { x: r.minX, y: r.maxY - r.h * 0.25, w: r.w, h: r.h * 0.25 };
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    ctx.fillRect(band.x, band.y, band.w, band.h);
    ctx.strokeStyle = css(accent, 0.9);
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (const cx of [0.22, 0.52, 0.80]) {
      ctx.moveTo(r.minX + r.w * cx, r.minY + r.h * 0.1);
      ctx.lineTo(r.minX + r.w * cx, r.minY + r.h * 0.45);
    }
    ctx.stroke();
  },

  stone(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.9);
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(r.minX, r.midY); ctx.lineTo(r.maxX, r.midY);
    ctx.moveTo(r.minX + r.w * 0.38, r.minY); ctx.lineTo(r.minX + r.w * 0.33, r.midY);
    ctx.moveTo(r.minX + r.w * 0.68, r.midY); ctx.lineTo(r.minX + r.w * 0.72, r.maxY);
    ctx.stroke();
    ctx.strokeStyle = css(accent, 0.6);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(r.minX + r.w * 0.15, r.minY + r.h * 0.25); ctx.lineTo(r.minX + r.w * 0.25, r.minY + r.h * 0.20);
    ctx.moveTo(r.minX + r.w * 0.55, r.minY + r.h * 0.70); ctx.lineTo(r.minX + r.w * 0.62, r.minY + r.h * 0.78);
    ctx.stroke();
  },

  sandstone(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.55);
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (const frac of [0.3, 0.55, 0.8]) {
      const y = r.minY + r.h * frac;
      ctx.moveTo(r.minX, y);
      ctx.lineTo(r.maxX, y + (frac === 0.55 ? 1 : -1));
    }
    ctx.stroke();
    for (const [gx, gy] of [[0.2, 0.15], [0.65, 0.4], [0.35, 0.68], [0.8, 0.9]]) {
      fillEllipse(ctx, r.minX + r.w * gx, r.minY + r.h * gy, 1.4, 1.4, css(accent, 0.45));
    }
  },

  water(ctx, r, accent) {
    const rows = 3;
    const rowH = r.h / rows;
    for (let row = 0; row < rows; row++) {
      const y = r.minY + rowH * row + rowH * 0.5;
      const seg = r.w / 2;
      ctx.strokeStyle = css(accent, 0.85 - row * 0.18);
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(r.minX, y);
      ctx.bezierCurveTo(r.minX + seg * 0.25, y - rowH * 0.30, r.minX + seg * 0.75, y + rowH * 0.30, r.minX + seg, y);
      ctx.bezierCurveTo(r.minX + seg * 1.25, y - rowH * 0.30, r.minX + seg * 1.75, y + rowH * 0.30, r.maxX, y);
      ctx.stroke();
    }
    for (const [gx, gy] of [[0.30, 0.18], [0.68, 0.30]]) {
      fillEllipse(ctx, r.minX + r.w * gx, r.minY + r.h * gy, 2, 1.4, 'rgba(255,255,255,0.7)');
    }
  },

  blossom(ctx, r, accent) {
    ctx.strokeStyle = css(accent);
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(r.midX, r.maxY); ctx.lineTo(r.midX, r.minY + r.h * 0.30);
    ctx.moveTo(r.midX, r.maxY - r.h * 0.45); ctx.lineTo(r.minX + r.w * 0.28, r.minY + r.h * 0.30);
    ctx.moveTo(r.midX, r.maxY - r.h * 0.30); ctx.lineTo(r.minX + r.w * 0.78, r.minY + r.h * 0.25);
    ctx.stroke();
    for (const [px, py] of [[0.22, 0.55], [0.68, 0.65], [0.45, 0.82]]) {
      fillEllipse(ctx, r.minX + r.w * px, r.minY + r.h * py, 1.6, 1.6, 'rgba(255,255,255,0.75)');
    }
  },

  neon(ctx, r, accent) {
    ctx.beginPath();
    ctx.moveTo(r.minX, r.minY); ctx.lineTo(r.maxX, r.maxY);
    ctx.moveTo(r.maxX, r.minY); ctx.lineTo(r.minX, r.maxY);
    ctx.strokeStyle = css(accent, 0.35); ctx.lineWidth = 4; ctx.stroke();
    ctx.strokeStyle = css(accent); ctx.lineWidth = 1.4; ctx.stroke();
  },

  coral(ctx, r, accent) {
    const baseX = r.minX + r.w * 0.42;
    ctx.strokeStyle = css(accent);
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(baseX, r.maxY); ctx.lineTo(baseX, r.minY + r.h * 0.35);
    ctx.moveTo(baseX, r.maxY - r.h * 0.35); ctx.lineTo(baseX - r.w * 0.16, r.minY + r.h * 0.40);
    ctx.moveTo(baseX, r.maxY - r.h * 0.50); ctx.lineTo(baseX + r.w * 0.20, r.minY + r.h * 0.28);
    ctx.moveTo(baseX + r.w * 0.20, r.minY + r.h * 0.55); ctx.lineTo(baseX + r.w * 0.34, r.minY + r.h * 0.42);
    ctx.stroke();
    for (const [bx, by] of [[0.82, 0.2], [0.12, 0.3]]) {
      strokeEllipse(ctx, r.minX + r.w * bx, r.minY + r.h * by, 2, 2, 'rgba(255,255,255,0.55)', 0.6);
    }
  },

  greenhouse(ctx, r, accent) {
    ctx.strokeStyle = 'rgba(255,255,255,0.45)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(r.midX, r.minY); ctx.lineTo(r.midX, r.maxY);
    ctx.moveTo(r.minX, r.midY); ctx.lineTo(r.maxX, r.midY);
    ctx.stroke();
    ctx.strokeStyle = css(accent);
    ctx.lineWidth = 1.2;
    for (const cx of [0.25, 0.72]) {
      const x = r.minX + r.w * cx;
      ctx.beginPath();
      ctx.moveTo(x, r.maxY); ctx.lineTo(x, r.maxY - r.h * 0.45);
      ctx.moveTo(x, r.maxY - r.h * 0.30); ctx.lineTo(x - r.w * 0.08, r.maxY - r.h * 0.42);
      ctx.moveTo(x, r.maxY - r.h * 0.38); ctx.lineTo(x + r.w * 0.08, r.maxY - r.h * 0.50);
      ctx.stroke();
    }
  },

  bookshelf(ctx, r, accent) {
    const colors = [css(accent), 'rgba(184,77,66,0.9)', 'rgba(82,117,82,0.9)', 'rgba(209,168,77,0.9)'];
    for (const shelfFrac of [0.0, 0.5]) {
      const shelfTop = r.minY + r.h * shelfFrac;
      const shelfH = r.h * 0.5;
      const bookW = r.w * 0.13;
      for (let i = 0; i < 5; i++) {
        const x = r.minX + r.w * 0.06 + i * bookW * 1.25;
        const hv = 0.72 + 0.16 * ((i + Math.round(shelfFrac * 2)) % 2);
        ctx.fillStyle = colors[i % colors.length];
        ctx.fillRect(x, shelfTop + shelfH * (1 - hv) - 1, bookW, shelfH * hv);
      }
      ctx.fillStyle = 'rgba(0,0,0,0.30)';
      ctx.fillRect(r.minX, shelfTop + shelfH - 1.4, r.w, 1.4);
    }
  },

  marble(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.55);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(r.minX, r.minY + r.h * 0.3);
    ctx.bezierCurveTo(r.minX + r.w * 0.35, r.minY + r.h * 0.15, r.minX + r.w * 0.6, r.minY + r.h * 0.75, r.maxX, r.minY + r.h * 0.55);
    ctx.stroke();
    ctx.strokeStyle = css(accent, 0.4);
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    ctx.moveTo(r.minX + r.w * 0.55, r.minY);
    ctx.bezierCurveTo(r.minX + r.w * 0.7, r.minY + r.h * 0.4, r.minX + r.w * 0.6, r.minY + r.h * 0.7, r.minX + r.w * 0.8, r.maxY);
    ctx.stroke();
  },

  circuit(ctx, r, accent) {
    ctx.strokeStyle = css(accent, 0.85);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(r.minX, r.minY + r.h * 0.30);
    ctx.lineTo(r.minX + r.w * 0.40, r.minY + r.h * 0.30);
    ctx.lineTo(r.minX + r.w * 0.40, r.minY + r.h * 0.72);
    ctx.lineTo(r.minX + r.w * 0.78, r.minY + r.h * 0.72);
    ctx.moveTo(r.maxX, r.minY + r.h * 0.42);
    ctx.lineTo(r.minX + r.w * 0.62, r.minY + r.h * 0.42);
    ctx.lineTo(r.minX + r.w * 0.62, r.minY + r.h * 0.18);
    ctx.stroke();
    ctx.fillStyle = css(accent);
    for (const [px, py] of [[0.78, 0.72], [0.62, 0.18]]) {
      ctx.fillRect(r.minX + r.w * px - 1.5, r.minY + r.h * py - 1.5, 3, 3);
    }
  },

  lava(ctx, r, accent) {
    const path = (ctx) => {
      ctx.beginPath();
      ctx.moveTo(r.minX, r.minY + r.h * 0.45);
      ctx.lineTo(r.minX + r.w * 0.30, r.minY + r.h * 0.60);
      ctx.lineTo(r.minX + r.w * 0.55, r.minY + r.h * 0.38);
      ctx.lineTo(r.maxX, r.minY + r.h * 0.52);
      ctx.moveTo(r.minX + r.w * 0.30, r.minY + r.h * 0.60);
      ctx.lineTo(r.minX + r.w * 0.42, r.maxY);
      ctx.moveTo(r.minX + r.w * 0.55, r.minY + r.h * 0.38);
      ctx.lineTo(r.minX + r.w * 0.62, r.minY);
    };
    ctx.strokeStyle = css(accent, 0.35); ctx.lineWidth = 3.5; path(ctx); ctx.stroke();
    ctx.strokeStyle = css(accent); ctx.lineWidth = 1.2; path(ctx); ctx.stroke();
  },

  gold(ctx, r) {
    const fx = r.minX + r.w * 0.12, fy = r.minY + r.h * 0.16;
    const fw = r.w * 0.76, fh = r.h * 0.68;
    const design = designForId('gold');
    ctx.strokeStyle = css(design.accent); ctx.lineWidth = 1.5;
    ctx.strokeRect(fx, fy, fw, fh);
    ctx.strokeStyle = 'rgba(0,0,0,0.2)'; ctx.lineWidth = 1;
    ctx.strokeRect(fx + 1.5, fy + 1.5, fw - 3, fh - 3);
  },

  clockwork(ctx, r, accent) {
    const cx = r.midX, cy = r.midY;
    const radius = Math.min(r.w, r.h) * 0.30;
    strokeEllipse(ctx, cx - radius, cy - radius, radius * 2, radius * 2, css(accent), 1.3);
    ctx.strokeStyle = css(accent); ctx.lineWidth = 1.2;
    ctx.beginPath();
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      ctx.moveTo(cx + Math.cos(a) * radius, cy + Math.sin(a) * radius);
      ctx.lineTo(cx + Math.cos(a) * (radius + 2), cy + Math.sin(a) * (radius + 2));
    }
    ctx.stroke();
    fillEllipse(ctx, cx - 1.5, cy - 1.5, 3, 3, css(accent));
  },

  observatory(ctx, r, accent) {
    ctx.fillStyle = 'rgba(255,255,255,0.14)';
    ctx.beginPath();
    ctx.arc(r.midX, r.minY + r.h * 0.55, r.w * 0.32, Math.PI, 0, false);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = css(accent);
    ctx.fillRect(r.midX - r.w * 0.05, r.minY + r.h * 0.12, r.w * 0.10, r.h * 0.40);
    for (const [sx, sy] of [[0.15, 0.2], [0.85, 0.25], [0.2, 0.75], [0.82, 0.7]]) {
      fillEllipse(ctx, r.minX + r.w * sx, r.minY + r.h * sy, 1.5, 1.5, css(accent, 0.9));
    }
  },

  moon(ctx, r, accent) {
    for (const [sx, sy] of [[0.16, 0.20], [0.84, 0.16], [0.74, 0.78], [0.22, 0.66]]) {
      fillEllipse(ctx, r.minX + r.w * sx, r.minY + r.h * sy, 1.4, 1.4, 'rgba(255,255,255,0.8)');
    }
    const radius = Math.min(r.w, r.h) * 0.34;
    const cx = r.minX + r.w * 0.42, cy = r.minY + r.h * 0.42;
    fillEllipse(ctx, cx - radius, cy - radius, radius * 2, radius * 2, css(accent));
    for (const [dx, dy, scale] of [[-0.10, -0.12, 0.30], [0.22, 0.08, 0.20], [-0.04, 0.28, 0.16]]) {
      const cr = radius * scale;
      fillEllipse(ctx, cx + radius * dx - cr, cy + radius * dy - cr, cr * 2, cr * 2, 'rgba(0,0,0,0.16)');
    }
  },

  cracked(ctx, r, accent) {
    ctx.strokeStyle = css(accent);
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(r.minX + r.w * 0.45, r.minY);
    ctx.lineTo(r.minX + r.w * 0.55, r.minY + r.h * 0.3);
    ctx.lineTo(r.minX + r.w * 0.38, r.minY + r.h * 0.55);
    ctx.lineTo(r.minX + r.w * 0.52, r.minY + r.h * 0.8);
    ctx.lineTo(r.minX + r.w * 0.46, r.maxY);
    ctx.moveTo(r.minX + r.w * 0.55, r.minY + r.h * 0.3);
    ctx.lineTo(r.minX + r.w * 0.75, r.minY + r.h * 0.42);
    ctx.moveTo(r.minX + r.w * 0.38, r.minY + r.h * 0.55);
    ctx.lineTo(r.minX + r.w * 0.2, r.minY + r.h * 0.65);
    ctx.stroke();
  },
};

function drawGardenBushes(ctx, r, accent) {
  const radii = [0.18, 0.24, 0.16];
  const centers = [0.22, 0.52, 0.80];
  for (let i = 0; i < centers.length; i++) {
    const rad = r.w * radii[i] * 0.5;
    fillEllipse(ctx, r.minX + r.w * centers[i] - rad, r.minY - rad * 0.9, rad * 2, rad * 2, css(accent));
  }
}

function drawBlossomCrowns(ctx, r) {
  const petal = 'rgb(250, 219, 230)';
  const radii = [0.20, 0.26, 0.18];
  const centers = [0.25, 0.55, 0.82];
  for (let i = 0; i < centers.length; i++) {
    const rad = r.w * radii[i] * 0.5;
    fillEllipse(ctx, r.minX + r.w * centers[i] - rad, r.minY - rad * 0.9, rad * 2, rad * 2, petal);
  }
}
