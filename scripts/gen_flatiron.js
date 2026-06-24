/** Generate the Flatiron ship (flatiron_ship.txt).
 *
 * True flatiron: pointed bow (top), continuous widening to stern (bottom).
 * Exterior: \ and / form diagonal hull edges, @ for flat borders, # for hull.
 * Interior: matches exterior boundary, frigate interior with rooms.
 */

const fs = require("fs");
const path = require("path");

const SHIP_DIR = path.join(__dirname, "..", "ships");
const W = 55;
const H = 40;
const MID = Math.floor(W / 2);

function calcWidth(r) {
  const t = r / (H - 1);
  let w = Math.floor(3 + 44 * Math.pow(t, 0.80));
  if (w % 2 === 0) w += 1;
  return w;
}

function makeExterior() {
  const grid = Array.from({ length: H }, () => Array(W).fill(" "));
  const widths = [];

  for (let r = 0; r < H; r++) {
    const w = calcWidth(r);
    widths.push(w);
    const L = (W - w) >> 1;
    const R = L + w - 1;

    if (r === 0) {
      for (let c = L; c <= R; c++) grid[r][c] = "@";
      continue;
    }

    const pw = widths[r - 1];
    const pL = (W - pw) >> 1;
    const pR = pL + pw - 1;

    if (w > pw) {
      // Ship widened — place \ and / at the new corner tiles
      // New left tiles
      for (let c = L; c < pL; c++) grid[r][c] = "\\";
      // New right tiles
      for (let c = pR + 1; c <= R; c++) grid[r][c] = "/";
      // Previous border tiles become interior fill
      for (let c = pL; c <= pR; c++) {
        if (c === pL || c === pR) grid[r][c] = "#";
        else grid[r][c] = "#";
      }
      // Fill any gap between new corners and old border
      for (let c = pL; c <= pR; c++) {
        if (grid[r][c] !== "#") grid[r][c] = "#";
      }
    } else {
      // Same width or narrower — flat border with @
      grid[r][L] = "@";
      for (let c = L + 1; c < R; c++) grid[r][c] = "#";
      grid[r][R] = "@";
    }
  }

  // Windows (o)
  for (const r of [7, 15, 23, 31]) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    if (R - L > 8) {
      grid[r][L + 3] = "o";
      grid[r][R - 3] = "o";
    }
  }

  // Panel detail lines ( - )
  for (const r of [5, 12, 19, 27, 34]) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    if (R - L > 10) {
      for (let c = L + 4; c <= R - 4; c++) {
        if (grid[r][c] === "#") grid[r][c] = "-";
      }
    }
  }

  // Damage (%)
  for (const [r, sc, n] of [[18, 4, 3], [18, W - 7, 3], [28, 6, 4], [28, W - 10, 4]]) {
    for (let i = 0; i < n; i++) {
      const c = sc + i;
      if (c >= 0 && c < W && grid[r][c] === "#") grid[r][c] = "%";
    }
  }

  // Airlocks (A) 
  for (const r of [13, 25]) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    grid[r][L] = "A";
    grid[r][R] = "A";
  }

  // Main thruster row (row H-2)
  for (const off of [-8, -4, 4, 8]) {
    const c = MID + off;
    if (c >= 0 && c < W) grid[H - 2][c] = "v";
  }
  // Bottom row (row H-1)
  for (const off of [-10, -6, -2, 2, 6, 10]) {
    const c = MID + off;
    if (c >= 0 && c < W) grid[H - 1][c] = "v";
  }

  return { grid: grid.map(row => row.join("")), widths };
}

function makeInterior(exterior, widths) {
  const grid = exterior.map(row => row.split(""));

  // First pass: map exterior chars to interior equivalents
  const hullBorder = new Set(["\\", "/", "@"]);
  const hullFill   = new Set(["#", "-", "|", "%", "v", "^", "<", ">"]);
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      const ch = grid[r][c];
      if (hullBorder.has(ch)) grid[r][c] = "@";
      else if (hullFill.has(ch)) grid[r][c] = ".";
      // A, o, " " stay as-is
    }
  }

  // Remember shared chars so we don't overwrite them
  const shared = new Set(["o", "A", "@", " "]);

  // Helper to check if position can be set (not a shared char)
  function setIfFree(r, c, ch) {
    if (r < 0 || r >= H || c < 0 || c >= W) return;
    if (!shared.has(grid[r][c])) grid[r][c] = ch;
  }

  // ── Bridge (rows 3-9) ──
  for (let r = 3; r <= 9; r++) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    const rl = L + 2, rr = R - 2;
    if (rl >= rr) continue;

    if (r === 3) {
      setIfFree(r, rl, "["); for (let c = rl + 1; c < rr; c++) setIfFree(r, c, "="); setIfFree(r, rr, "]");
    } else if (r === 9) {
      setIfFree(r, rl, "{"); for (let c = rl + 1; c < rr; c++) setIfFree(r, c, "="); setIfFree(r, rr, "}");
    } else {
      setIfFree(r, rl, "!"); setIfFree(r, rr, "!");
      for (let c = rl + 1; c < rr; c++) setIfFree(r, c, ".");
    }
  }

  setIfFree(5, MID, "C");
  setIfFree(5, MID - 3, "*"); setIfFree(5, MID + 3, "*");
  setIfFree(6, MID - 2, "*"); setIfFree(6, MID + 2, "*");

  // ── Crew quarters (rows 11-21) ──
  for (let r = 11; r <= 21; r++) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;

    // Central corridor (5 wide)
    for (let c = MID - 2; c <= MID + 2; c++) {
      if (c > L && c < R) setIfFree(r, c, ".");
    }

    // Left room
    const rl = L + 2;
    const rm = MID - 3;
    if (rl < rm) {
      if (r === 11) {
        setIfFree(r, rl, "["); for (let c = rl + 1; c < rm; c++) setIfFree(r, c, "="); setIfFree(r, rm, "]");
      } else if (r === 21) {
        setIfFree(r, rl, "{"); for (let c = rl + 1; c < rm; c++) setIfFree(r, c, "="); setIfFree(r, rm, "}");
      } else {
        setIfFree(r, rl, "!"); setIfFree(r, rm, "!");
        for (let c = rl + 1; c < rm; c++) setIfFree(r, c, ".");
      }
    }

    // Right room
    const lm = MID + 3;
    const rr2 = R - 2;
    if (lm < rr2) {
      if (r === 11) {
        setIfFree(r, lm, "["); for (let c = lm + 1; c < rr2; c++) setIfFree(r, c, "="); setIfFree(r, rr2, "]");
      } else if (r === 21) {
        setIfFree(r, lm, "{"); for (let c = lm + 1; c < rr2; c++) setIfFree(r, c, "="); setIfFree(r, rr2, "}");
      } else {
        setIfFree(r, lm, "!"); setIfFree(r, rr2, "!");
        for (let c = lm + 1; c < rr2; c++) setIfFree(r, c, ".");
      }
    }
  }

  // ── Engine room (rows 29-37) ──
  for (let r = 29; r <= 37; r++) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    const rl = L + 2, rr = R - 2;
    if (rl >= rr) continue;

    if (r === 29) {
      setIfFree(r, rl, "["); for (let c = rl + 1; c < rr; c++) setIfFree(r, c, "="); setIfFree(r, rr, "]");
    } else if (r === 37) {
      setIfFree(r, rl, "{"); for (let c = rl + 1; c < rr; c++) setIfFree(r, c, "="); setIfFree(r, rr, "}");
    } else {
      setIfFree(r, rl, "!"); setIfFree(r, rr, "!");
      for (let c = rl + 1; c < rr; c++) setIfFree(r, c, ".");
    }
  }

  // Energy conduits — use L+4 and R-4 to avoid overlapping windows at L+3
  for (let r = 30; r <= 36; r++) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    setIfFree(r, L + 4, "~");
    setIfFree(r, R - 4, "~");
  }

  // Equipment consoles
  for (const r of [31, 33, 35]) {
    const w = widths[r];
    const L = (W - w) >> 1;
    const R = L + w - 1;
    setIfFree(r, L + 6, "*");
    setIfFree(r, R - 6, "*");
  }

  // Vertical corridor connecting bridge → crew → engine (middle column)
  for (let r = 10; r <= 28; r++) {
    setIfFree(r, MID, ".");
  }

  return grid.map(row => row.join(""));
}

function findThrusters(exterior) {
  const map = { v: "down", "^": "up", "<": "left", ">": "right" };
  const out = [];
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      const d = map[exterior[r][c]];
      if (d) out.push([r + 1, c + 1, d]);
    }
  }
  return out;
}

function verify(exterior, interior, widths) {
  const errors = [];

  if (exterior.length !== H) errors.push(`Exterior rows: ${exterior.length} (need ${H})`);
  if (interior.length !== H) errors.push(`Interior rows: ${interior.length} (need ${H})`);

  for (let i = 0; i < H; i++) {
    if (exterior[i].length !== W) errors.push(`Ext row ${i+1} len ${exterior[i].length}`);
    if (interior[i].length !== W) errors.push(`Int row ${i+1} len ${interior[i].length}`);
  }

  // Exterior->interior boundary mapping
  const extIn = { "@": "@", "\\": "@", "/": "@", A: "A", o: "o", " ": " " };
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      const ec = exterior[r][c];
      const ic = interior[r][c];
      if (ec in extIn && ic !== extIn[ec]) {
        errors.push(`Row ${r+1} col ${c+1}: ext '${ec}' -> int '${ic}' (expect '${extIn[ec]}')`);
      }
    }
  }

  // No exterior-only chars in interior
  const extOnly = new Set(["#", "%", "/", "\\", "v", "^", "<", ">"]);
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      if (extOnly.has(interior[r][c]))
        errors.push(`Int row ${r+1} col ${c+1}: ext-only '${interior[r][c]}'`);
    }
  }

  // No interior-only chars in exterior
  const intOnly = new Set([".", "[", "]", "{", "}", "=", "!", "+", "~", "C"]);
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      if (intOnly.has(exterior[r][c]))
        errors.push(`Ext row ${r+1} col ${c+1}: int-only '${exterior[r][c]}'`);
    }
  }

  return errors;
}

function main() {
  const { grid: exterior, widths } = makeExterior();
  const interior = makeInterior(exterior, widths);
  const thrusters = findThrusters(exterior);

  const lines = [
    "name: Flatiron", "font_size: 24", "",
    "[exterior]", ...exterior, "",
    "[interior]", ...interior, "",
    "[thrusters]", ...thrusters.map(t => `${t[0]},${t[1]},${t[2]}`)
  ];

  fs.mkdirSync(SHIP_DIR, { recursive: true });
  const outPath = path.join(SHIP_DIR, "flatiron_ship.txt");
  fs.writeFileSync(outPath, lines.join("\n") + "\n");

  console.log(`Exterior: ${exterior.length} rows, Interior: ${interior.length} rows, Thrusters: ${thrusters.length}`);

  const errors = verify(exterior, interior, widths);
  for (const e of errors) console.log(`  ERROR: ${e}`);
  if (errors.length === 0) console.log("All checks PASSED");

  console.log("\n=== EXTERIOR ===");
  exterior.forEach((row, i) => console.log(`${String(i+1).padStart(2)} |${row}|`));
  console.log("\n=== INTERIOR ===");
  interior.forEach((row, i) => console.log(`${String(i+1).padStart(2)} |${row}|`));
}

main();
