#!/usr/bin/env node
// Genera docs/CODE_MAP.md a partir de lib/ y test/.
// Uso:
//   node scripts/gen_code_map.js           -> escribe docs/CODE_MAP.md
//   node scripts/gen_code_map.js --check   -> falla si el archivo esta desactualizado
// Sin dependencias externas. Salida deterministica (sin fechas) para evitar ruido en diffs.

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const LIB = path.join(ROOT, 'lib');
const TEST = path.join(ROOT, 'test');
const OUT = path.join(ROOT, 'docs', 'CODE_MAP.md');

function walk(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile() && entry.name.endsWith('.dart')) out.push(full);
  }
  return out;
}

function packageName() {
  const pubspec = path.join(ROOT, 'pubspec.yaml');
  if (!fs.existsSync(pubspec)) return '';
  const match = fs.readFileSync(pubspec, 'utf8').match(/^name:\s*(\S+)/m);
  return match ? match[1] : '';
}

const PKG = packageName();

function toPosix(p) {
  return p.split(path.sep).join('/');
}

// Simbolos publicos de nivel superior.
function extractSymbols(source) {
  const symbols = [];
  const re = /^(?:abstract\s+|sealed\s+|base\s+|final\s+)?(class|mixin|enum|typedef)\s+([A-Za-z_]\w*)/gm;
  let m;
  while ((m = re.exec(source)) !== null) {
    const name = m[2];
    if (!name.startsWith('_') && !symbols.includes(name)) symbols.push(name);
  }
  return symbols;
}

// Mapa archivo lib -> pruebas que lo importan.
function buildTestIndex(libFiles) {
  const index = new Map();
  for (const file of libFiles) {
    const rel = toPosix(path.relative(ROOT, file));
    const importPath = `package:${PKG}/${rel.slice('lib/'.length)}`;
    index.set(rel, { importPath, tests: [] });
  }
  for (const testFile of walk(TEST)) {
    const source = fs.readFileSync(testFile, 'utf8');
    const testRel = toPosix(path.relative(ROOT, testFile));
    for (const [libRel, entry] of index) {
      if (source.includes(entry.importPath)) entry.tests.push(testRel);
    }
  }
  return index;
}

function cell(list, limit) {
  if (list.length === 0) return '-';
  const shown = list.slice(0, limit).map((s) => '`' + s + '`');
  if (list.length > limit) shown.push(`+${list.length - limit}`);
  return shown.join(', ');
}

function build() {
  const libFiles = walk(LIB).sort();
  const testIndex = buildTestIndex(libFiles);

  const layers = new Map();
  for (const file of libFiles) {
    const rel = toPosix(path.relative(ROOT, file));
    const parts = rel.split('/');
    const layer = parts.length > 2 ? parts[1] : '(raiz)';
    const source = fs.readFileSync(file, 'utf8');
    const lines = source.split('\n').length;
    const symbols = extractSymbols(source);
    const page = {
      file: rel,
      lines,
      symbols,
      tests: (testIndex.get(rel) || { tests: [] }).tests.map((t) => path.posix.basename(t)),
    };
    if (!layers.has(layer)) layers.set(layer, []);
    layers.get(layer).push(page);
  }

  const order = ['core', 'data', 'domain', 'providers', 'services', 'ui', '(raiz)'];
  const layerNames = [...layers.keys()].sort((a, b) => {
    const ia = order.indexOf(a);
    const ib = order.indexOf(b);
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib) || a.localeCompare(b);
  });

  const out = [];
  out.push('# Mapa de Código (generado)');
  out.push('');
  out.push('> Archivo generado por `node scripts/gen_code_map.js`. No lo edites a mano.');
  out.push('> Regenerar tras tocar `lib/` o `test/`: `node scripts/gen_code_map.js`.');
  out.push('> El hook de pre-commit lo actualiza y lo añade al commit.');
  out.push('');
  out.push('## Resumen');
  out.push('');
  out.push('| Capa | Archivos | Líneas |');
  out.push('|---|---|---|');
  let totalFiles = 0;
  let totalLines = 0;
  for (const layer of layerNames) {
    const pages = layers.get(layer);
    const lines = pages.reduce((acc, p) => acc + p.lines, 0);
    totalFiles += pages.length;
    totalLines += lines;
    out.push(`| \`${layer}/\` | ${pages.length} | ${lines} |`);
  }
  out.push(`| **Total** | **${totalFiles}** | **${totalLines}** |`);
  out.push('');

  for (const layer of layerNames) {
    const pages = layers.get(layer);
    out.push(`## ${layer}/`);
    out.push('');
    out.push('| Archivo | Líneas | Símbolos | Pruebas |');
    out.push('|---|---|---|---|');
    for (const page of pages.sort((a, b) => a.file.localeCompare(b.file))) {
      const fileCell = '`' + page.file + '`';
      out.push(`| ${fileCell} | ${page.lines} | ${cell(page.symbols, 4)} | ${cell(page.tests, 3)} |`);
    }
    out.push('');
  }

  return out.join('\n');
}

const content = build();
const check = process.argv.includes('--check');
const normalize = (text) => text.replace(/\r\n/g, '\n').trimEnd() + '\n';

const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;

if (check) {
  if (existing === null) {
    console.error('[CODE_MAP] Falta docs/CODE_MAP.md. Ejecuta: node scripts/gen_code_map.js');
    process.exit(1);
  }
  if (normalize(existing) !== normalize(content)) {
    console.error('[CODE_MAP] docs/CODE_MAP.md esta desactualizado. Ejecuta: node scripts/gen_code_map.js');
    process.exit(1);
  }
  console.log('[CODE_MAP] OK');
  process.exit(0);
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, normalize(content), 'utf8');
console.log(`[CODE_MAP] Escrito ${toPosix(path.relative(ROOT, OUT))} (${content.length} bytes)`);
