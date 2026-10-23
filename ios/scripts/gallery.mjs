#!/usr/bin/env node
// Builds ios/validation/<fase>/index.html — the app × web gallery of one
// phase — from that phase's checklist table in ios/README.md ("Validação
// visual" → "### Fase <fase>"). One row per table line:
//
//   | # | Tela | Estado | App | Web | Resultado |
//   | 03 | Perfil | escuro · PT | `SOTREINA_SCREEN=profile SOTREINA_THEME=dark` | `--page profile --theme dark` | ✓ |
//
// Images are found by number: <#>-app.png (ios/scripts/screenshot.sh) and
// <#>-web.png (run-sotreina driver --iphone --file). Web "—" = app-only
// surface (Live Activity, Dynamic Type, native sheet). Missing files show
// as a gap, so the page doubles as "what's left to capture".
//
//   node ios/scripts/gallery.mjs S
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const IOS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fase = process.argv[2];
if (!fase) {
  console.error('usage: node ios/scripts/gallery.mjs <fase>   (e.g. S, T, D)');
  process.exit(1);
}

function parseChecklist(readme, fase) {
  const lines = readme.split('\n');
  const section = lines.findIndex((l) => /^## Validação visual\s*$/.test(l));
  if (section < 0) throw new Error('no "## Validação visual" section in ios/README.md');
  const heading = lines.findIndex((l, i) => i > section && l.trim() === `### Fase ${fase}`);
  if (heading < 0) throw new Error(`no "### Fase ${fase}" under "## Validação visual"`);

  const rows = [];
  for (let i = heading + 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (/^#{2,3} /.test(line)) break; // next phase or section
    if (!line.startsWith('|')) continue;
    const cells = line.slice(1, line.endsWith('|') ? -1 : undefined).split('|').map((c) => c.trim());
    if (!/^\d+$/.test(cells[0])) continue; // header and --- separator
    const [id, tela, estado, , web, resultado = ''] = cells; // App = launch.sh args
    rows.push({
      id: id.padStart(2, '0'),
      tela,
      estado,
      web: web.replace(/^`|`$/g, ''),
      appOnly: web === '—' || web === '-',
      resultado,
    });
  }
  return rows;
}

const esc = (s) =>
  s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

function cell(dir, file, emptyText) {
  return fs.existsSync(path.join(dir, file))
    ? `<a href="${file}"><img src="${file}" alt="${file}" loading="lazy"></a>`
    : `<div class="gap">${esc(emptyText)}</div>`;
}

function verdict(r) {
  if (!r) return { cls: 'todo', text: 'a conferir' };
  if (r.startsWith('✓')) return { cls: 'ok', text: r };
  if (/^bug/i.test(r)) return { cls: 'bug', text: r };
  return { cls: 'dev', text: r }; // desvio aceito + motivo
}

const rows = parseChecklist(fs.readFileSync(path.join(IOS, 'README.md'), 'utf-8'), fase);
const dir = path.join(IOS, 'validation', fase);
fs.mkdirSync(dir, { recursive: true });

const body = rows
  .map((r) => {
    const v = verdict(r.resultado);
    return `<section>
  <header>
    <span class="id">${r.id}</span>
    <h2>${esc(r.tela)} · ${esc(r.estado)}</h2>
    <span class="v ${v.cls}">${esc(v.text)}</span>
  </header>
  <div class="pair">
    <figure><figcaption>app</figcaption>${cell(dir, `${r.id}-app.png`, 'falta captura do app')}</figure>
    <figure><figcaption>web${r.appOnly ? '' : ` <code>${esc(r.web)}</code>`}</figcaption>${
      r.appOnly
        ? '<div class="gap">só app — comparar com a spec e o design system</div>'
        : cell(dir, `${r.id}-web.png`, 'falta captura da web')
    }</figure>
  </div>
</section>`;
  })
  .join('\n');

const html = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Validação · Fase ${esc(fase)}</title>
<style>
  :root { --bg: #f4f3f0; --fg: #141414; --muted: #6b6a66; --line: #dcdad4; --card: #fff; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #0b0b0c; --fg: #eeede9; --muted: #8f8e8a; --line: #2a2a2c; --card: #151516; }
  }
  body { margin: 0; padding: 24px 16px 64px; background: var(--bg); color: var(--fg);
         font: 14px/1.4 system-ui, sans-serif; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .sub { color: var(--muted); margin: 0 0 24px; }
  section { border-top: 1px solid var(--line); padding: 16px 0 24px; }
  header { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; margin-bottom: 12px; }
  h2 { font-size: 15px; margin: 0; flex: 1; }
  .id { font-family: ui-monospace, monospace; color: var(--muted); }
  .v { font-size: 12px; padding: 2px 8px; border-radius: 999px; background: var(--card); }
  .ok { color: #2f7d4f; } .bug { color: #c0392b; } .dev { color: #b07d1a; } .todo { color: var(--muted); }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 360px)); gap: 16px; }
  figure { margin: 0; min-width: 0; }
  figcaption { font-size: 12px; color: var(--muted); margin-bottom: 6px; overflow-wrap: anywhere; }
  img { display: block; width: 100%; height: auto; border-radius: 12px; outline: 1px solid var(--line); }
  .gap { aspect-ratio: 1179 / 2556; display: grid; place-items: center; text-align: center; padding: 16px;
         border: 1px dashed var(--line); border-radius: 12px; color: var(--muted); }
  code { font-size: 11px; }
</style>
</head>
<body>
<h1>Validação visual · Fase ${esc(fase)}</h1>
<p class="sub">${rows.length} pares · gerado de ios/README.md em ${new Date().toLocaleString('pt-BR')}</p>
${body || '<p class="sub">Checklist vazio.</p>'}
</body>
</html>
`;

const file = path.join(dir, 'index.html');
fs.writeFileSync(file, html);
console.log(file);
