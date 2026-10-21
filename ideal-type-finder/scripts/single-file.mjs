// Inline the Vite build into one self-contained HTML file (dist/single.html)
// for hosts that serve a single page. Optional: SHARE_BASE=<url> sets the
// address that share links point to.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dist = new URL('../dist/', import.meta.url).pathname;
const html = readFileSync(join(dist, 'index.html'), 'utf8');

const css = [...html.matchAll(/<link rel="stylesheet"[^>]*href="\.\/(assets\/[^"]+\.css)"[^>]*>/g)].map((m) => readFileSync(join(dist, m[1]), 'utf8'));
const js = [...html.matchAll(/<script type="module"[^>]*src="\.\/(assets\/[^"]+\.js)"[^>]*><\/script>/g)].map((m) =>
  readFileSync(join(dist, m[1]), 'utf8').replace(/<\/script/gi, '<\\/script'),
);
const fonts = html.match(/<link rel="stylesheet" href="https:\/\/fonts[^>]+>/)?.[0] ?? '';
const shareBase = process.env.SHARE_BASE ? `<meta name="share-base" content="${process.env.SHARE_BASE}">\n` : '';

const out = `<title>Ideal Type Finder</title>
<meta name="claude:viewport-fit-sides" content="cover">
${shareBase}${fonts}
<style>${css.join('\n')}</style>
<div id="root"></div>
<script type="module">${js.join('\n')}</script>
`;
writeFileSync(join(dist, 'single.html'), out);
console.log(`dist/single.html: ${(out.length / 1024).toFixed(0)} KB`);
