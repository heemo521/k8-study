// Screenshot tour of the main flows (390px phone) into docs/tour/.
// Serve build/web first (see check.cjs), then: node tour.cjs
const { chromium } = require('playwright');
const OUT = require('path').resolve(__dirname, '../../docs/tour');
const BASE = process.env.BASE_URL || 'http://localhost:8080/';
const W = 390, H = 844;

async function waitApp(p) {
  await p.waitForFunction(() => !document.getElementById('splash'), null, { timeout: 60000 });
  const ph = await p.$('flt-semantics-placeholder'); if (ph) await ph.dispatchEvent('click');
  await p.waitForSelector('flt-semantics', { timeout: 20000 });
  await p.waitForTimeout(900);
}
async function go(p, r) { await p.goto(BASE + '#' + r); await waitApp(p); }
async function find(p, text, exact) {
  return p.locator('flt-semantics').evaluateAll((els, [t, ex]) => {
    let f = null;
    for (const e of els) {
      const r = e.getBoundingClientRect();
      if (r.height <= 0 || r.bottom <= 0 || r.top >= window.innerHeight - 4) continue;
      const l = (e.getAttribute('aria-label') || '').trim(), c = (e.textContent || '').trim();
      if (ex ? (l === t || c === t) : (l.includes(t) || c.includes(t))) f = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    }
    return f;
  }, [text, exact]);
}
async function scroll(p, px) { await p.mouse.move(6, H / 2); await p.mouse.wheel(0, px); await p.waitForTimeout(350); }
async function tap(p, text, exact = true) {
  let pt = null;
  for (let k = 0; k < 30 && !pt; k++) { pt = await find(p, text, exact); if (!pt) await scroll(p, 250); }
  if (!pt) throw new Error('no ' + text);
  await p.mouse.click(pt.x, pt.y);
  await p.waitForTimeout(700);
}
async function pickOption(p) {
  const pt = await p.locator('flt-semantics').evaluateAll((els) => {
    const controls = new Set(['Close', 'All questions', 'Flag for review', 'Previous', 'Next', 'Finish test', 'Submit', 'Sure', 'Not sure', 'How sure are you?', 'See results']);
    for (const e of els) {
      const r = e.getBoundingClientRect();
      const t = (e.textContent || '').trim();
      if (e.getAttribute('role') !== 'button' || r.height <= 0 || controls.has(t) || !t) continue;
      return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    }
    return null;
  });
  if (!pt) throw new Error('no option');
  await p.mouse.click(pt.x, pt.y);
  await p.waitForTimeout(500);
}
async function shot(p, n) { await p.waitForTimeout(500); await p.screenshot({ path: `${OUT}/${n}.png` }); console.log('shot', n); }

(async () => {
  const b = await chromium.launch({ args: ['--enable-unsafe-swiftshader'] });
  const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'en-US' });
  // Headless Chromium has no TTS voices: stand in a silent one so the
  // read-aloud player can be shown speaking.
  await ctx.addInitScript(() => {
    Object.defineProperty(SpeechSynthesisUtterance.prototype, 'voice', { set() {}, get() { return null; } });
    speechSynthesis.getVoices = () => [{ name: 'Demo', lang: 'en-US', localService: true, default: true, voiceURI: 'demo' }];
    speechSynthesis.speak = () => {};
  });
  const p = await ctx.newPage();

  await go(p, '/');                                   await shot(p, '01-home');
  await tap(p, 'Got it');
  await go(p, '/topic/pods');                         await shot(p, '02-topic');

  // Notes with an animated diagram, stepped to step 3.
  await go(p, '/topic/architecture/notes');
  await scroll(p, 250);
  for (let k = 0; k < 3; k++) await tap(p, 'Next step');
  await shot(p, '03-diagram-walkthrough');

  // Read-aloud.
  await go(p, '/topic/namespaces/notes');
  await tap(p, 'Listen');
  await p.waitForTimeout(800);                        await shot(p, '04-read-aloud');
  await tap(p, 'Stop');

  // Flashcards.
  await go(p, '/topic/pods/cards');
  await tap(p, 'Show answer', false);                 await shot(p, '05-flashcard');

  // Topic quiz with feedback.
  await go(p, '/topic/pods/quiz');
  await pickOption(p);
  await tap(p, 'Sure');                             await shot(p, '06-quiz-feedback');

  // Mock exam -> gaps -> plan.
  await go(p, '/practice');                           await shot(p, '07-practice');
  await go(p, '/practice/cka-mock/run');
  await pickOption(p);                                await shot(p, '08-exam');
  await tap(p, 'Finish test');
  await tap(p, 'Finish');                             await shot(p, '09-exam-result-gaps');
  await tap(p, 'Build my gap plan', false);
  await p.waitForTimeout(800);                        await shot(p, '10-gap-plan');
  await go(p, '/');
  await scroll(p, 300);                               await shot(p, '11-home-with-plan');
  await go(p, '/progress');                           await shot(p, '12-progress');
  await ctx.close();

  // Dark mode.
  const dark = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, colorScheme: 'dark', locale: 'en-US' });
  const d = await dark.newPage();
  await go(d, '/topic/deployments/notes');
  await scroll(d, 300);
  await tap(d, 'Next step');                          await shot(d, '13-dark-diagram');
  await b.close();
})().catch((e) => { console.error(e); process.exit(1); });
