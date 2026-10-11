// Headless Chromium checks for the built PWA (spec §11, items 3–5).
//
//   flutter build web --release --no-web-resources-cdn
//   dart run tool/gen_precache.dart
//   python3 -m http.server 8080 --directory build/web   # any static server
//   (cd tool/pwa_check && npm install && npm run check)
//
// Env: BASE_URL (default http://localhost:8080/), SHOT_DIR (default
// ../../docs/screenshots), CHROMIUM_PATH (optional executable).
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE = process.env.BASE_URL || 'http://localhost:8080/';
const SHOT_DIR = path.resolve(__dirname, process.env.SHOT_DIR || '../../docs/screenshots');
const CONTENT_DIR = path.resolve(__dirname, '../../assets/content/subjects/kubernetes');
const PHONE = { width: 390, height: 844 };

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

const strip = (s) => s.replace(/\*\*|`/g, '');

async function waitApp(page) {
  await page.waitForFunction(() => !document.getElementById('splash'), null, { timeout: 60000 });
  const placeholder = await page.$('flt-semantics-placeholder');
  if (placeholder) await placeholder.dispatchEvent('click');
  await page.waitForSelector('flt-semantics', { timeout: 20000 });
  await page.waitForTimeout(400);
}

async function go(page, route) {
  await page.goto(`${BASE}#${route}`);
  await waitApp(page);
}

// Index of the last on-screen semantics node whose aria-label or text
// matches. Flutter also keeps semantics for a cache area outside the
// viewport; those nodes can't be clicked, so they're ignored.
async function findIndex(page, text, exact) {
  return page.locator('flt-semantics').evaluateAll((els, [t, ex]) => {
    let found = -1;
    els.forEach((e, i) => {
      const r = e.getBoundingClientRect();
      if (r.height <= 0 || r.bottom <= 0 || r.top >= window.innerHeight) return;
      const label = (e.getAttribute('aria-label') || '').trim();
      const content = (e.textContent || '').trim();
      const hit = ex ? label === t || content === t : label.includes(t) || content.includes(t);
      if (hit) found = i;
    });
    return found;
  }, [text, exact]);
}

async function tap(page, text, exact = true) {
  let idx = -1;
  for (let i = 0; i < 40 && idx < 0; i++) {
    idx = await findIndex(page, text, exact);
    if (idx >= 0) break;
    // Present but off-screen? Scroll towards it; otherwise wait for a frame.
    if (await hasText(page, text)) await scrollDown(page, 300);
    else await page.waitForTimeout(250);
  }
  if (idx < 0) throw new Error(`no semantics node for "${text}"`);
  const el = page.locator('flt-semantics').nth(idx);
  await el.click({ force: true });
  await page.waitForTimeout(450);
}

// Flutter's semantics tree lives in a shadow root; Playwright's CSS engine
// pierces it, document.body.innerText does not.
async function allText(page) {
  const parts = await page.locator('flt-semantics').evaluateAll((els) =>
    els.map((e) => `${e.getAttribute('aria-label') || ''} ${e.textContent || ''}`));
  return parts.join('\n');
}

async function hasText(page, text) {
  return (await allText(page)).includes(text);
}

async function shot(page, name) {
  fs.mkdirSync(SHOT_DIR, { recursive: true });
  await page.screenshot({ path: path.join(SHOT_DIR, `${name}.png`) });
}

async function scrollDown(page, px = 500) {
  // Wheel over the left page margin so horizontally scrolling code blocks
  // and tables don't swallow the vertical scroll.
  await page.mouse.move(6, PHONE.height / 2);
  await page.mouse.wheel(0, px);
  await page.waitForTimeout(250);
}

async function noHorizontalScroll(page) {
  return page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth);
}

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    args: ['--enable-unsafe-swiftshader'],
  });
  // Explicit locale: some headless environments report "en-US@posix".
  const ctx = await browser.newContext({
    viewport: PHONE, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'en-US',
  });
  const page = await ctx.newPage();
  const pageErrors = [];
  page.on('pageerror', (e) => pageErrors.push(e.message));

  // ---- Load, manifest, service worker, installability ----------------------
  await go(page, '/');
  check('app renders at 390×844', await hasText(page, 'topics complete'));
  await shot(page, '01-home');

  const cdp = await ctx.newCDPSession(page);
  const manifest = await cdp.send('Page.getAppManifest');
  check('manifest parses without errors', manifest.errors.length === 0,
    manifest.errors.map((e) => e.message).join('; '));
  const parsed = JSON.parse(manifest.data || '{}');
  check('manifest fields', parsed.display === 'standalone' && parsed.name === 'K8 Study' &&
    (parsed.icons || []).some((i) => i.sizes === '512x512' && i.purpose === 'maskable'));

  await page.waitForFunction(() => navigator.serviceWorker.controller !== null, null, { timeout: 30000 })
    .catch(() => {});
  const sw = await page.evaluate(async () => {
    const keys = await caches.keys();
    const own = keys.filter((k) => k.startsWith('k8study-'));
    const count = own.length ? (await (await caches.open(own[0])).keys()).length : 0;
    return { controlled: !!navigator.serviceWorker.controller, caches: own, count };
  });
  check('service worker controls the page', sw.controlled);
  check('precache populated', sw.caches.length === 1 && sw.count >= 30, `${sw.caches} (${sw.count} entries)`);

  const install = await cdp.send('Page.getInstallabilityErrors');
  check('installable (no installability errors)', install.installabilityErrors.length === 0,
    install.installabilityErrors.map((e) => e.errorId).join(', '));

  // ---- Full loop: study → flashcards → quiz → results ----------------------
  const topic = JSON.parse(fs.readFileSync(path.join(CONTENT_DIR, 'topics/namespaces.json'), 'utf8'));
  await tap(page, topic.title, false);
  await shot(page, '02-topic');
  await tap(page, '1. Study notes', false);
  await shot(page, '03-notes');
  for (let i = 0; i < 60; i++) {
    const mark = await findIndex(page, 'Mark read', true);
    if (mark >= 0) {
      await page.locator('flt-semantics').nth(mark).click({ force: true });
      await page.waitForTimeout(250);
      continue;
    }
    if ((await findIndex(page, 'Next: Flashcards', true)) >= 0) break;
    await scrollDown(page);
  }
  const total = topic.sections.length;
  check('all note sections marked read', await hasText(page, `${total}/${total}`));
  await shot(page, '04-notes-end');

  await tap(page, 'Next: Flashcards', false);
  await shot(page, '05-flashcard');
  for (let i = 0; i < 40 && !(await hasText(page, 'Session done')); i++) {
    await tap(page, 'Show answer (Space)', false);
    if (i === 0) await shot(page, '06-flashcard-back');
    await tap(page, 'Got it (2)', false);
  }
  check('flashcard session completed', await hasText(page, 'Session done'));

  await tap(page, 'Next: Quiz', false);
  for (let i = 0; i < 10; i++) {
    const text = await allText(page);
    const q = topic.questions.find((x) => text.includes(strip(x.stem)));
    if (!q) { check(`quiz question ${i + 1} identified`, false); break; }
    const picks = i === 0 ? [q.options.find((o) => !o.correct)] : q.options.filter((o) => o.correct);
    for (const o of picks) await tap(page, strip(o.text), false);
    if (i === 0) await shot(page, '07-quiz-question');
    await tap(page, 'Submit');
    if (i === 0) await shot(page, '08-quiz-feedback');
    await tap(page, i === 9 ? 'See results' : 'Next');
  }
  check('quiz results show 90%', await hasText(page, '90%'));
  await shot(page, '09-quiz-results');

  // ---- Persistence across reload --------------------------------------------
  await go(page, '/');
  const topicCount = JSON.parse(fs.readFileSync(path.join(CONTENT_DIR, 'subject.json'), 'utf8')).topics.length;
  check('progress persists after reload', await hasText(page, `1 of ${topicCount} topics complete`));
  await shot(page, '10-home-after');

  // ---- Gaps view and search -------------------------------------------------
  await go(page, '/progress');
  check('readiness shows accuracy for answered questions', await hasText(page, '% accuracy on'));
  await shot(page, '15-progress-readiness');
  for (let i = 0; i < 6 && !(await findIndex(page, 'Knowledge gaps', true) >= 0); i++) await scrollDown(page, 400);
  check('gap analysis section present', await hasText(page, 'Knowledge gaps'));
  await shot(page, '16-progress-gaps');
  await go(page, '/search');
  await page.keyboard.type('taint');
  await page.waitForTimeout(800);
  check('search returns results', await hasText(page, 'results'));
  await shot(page, '17-search');

  // ---- Practice test ---------------------------------------------------------
  await go(page, '/practice');
  await tap(page, 'Cluster Architecture, Installation & Configuration', false);
  await tap(page, 'Start');
  check('practice timer shown', /\b\d{2}:\d{2}\b/.test(await allText(page)));
  await shot(page, '11-practice-run');
  await tap(page, 'Finish test');
  await tap(page, 'Finish');
  check('practice per-domain breakdown', await hasText(page, 'By CKA domain'));
  await shot(page, '12-practice-results');

  // ---- No horizontal scroll at 390 and 360 ----------------------------------
  const routes = ['/', '/topic/kubeadm', '/topic/kubeadm/notes', '/topic/kubeadm/cards',
    '/topic/kubeadm/quiz', '/practice', '/progress', '/about'];
  for (const width of [390, 360]) {
    await page.setViewportSize({ width, height: 800 });
    let ok = true;
    for (const r of routes) {
      await go(page, r);
      if (!(await noHorizontalScroll(page))) { ok = false; console.log(`  overflow at ${width}px: ${r}`); }
    }
    check(`no horizontal page scroll at ${width}px`, ok);
  }
  await page.setViewportSize(PHONE);
  await go(page, '/about');
  await shot(page, '13-about');
  check('About shows CC BY 4.0 attribution', await hasText(page, 'CC BY 4.0'));

  // ---- Offline ---------------------------------------------------------------
  await ctx.setOffline(true);
  await page.reload();
  await waitApp(page);
  check('offline reload renders the app', await hasText(page, 'K8 Study'));
  await go(page, '/topic/kubeadm/notes');
  check('offline: topic notes render', await hasText(page, '1. Prepare the hosts'));
  await shot(page, '14-offline-notes');
  await ctx.setOffline(false);

  check('no uncaught page errors', pageErrors.length === 0, pageErrors.join(' | '));
  await browser.close();

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  process.exit(failed.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
