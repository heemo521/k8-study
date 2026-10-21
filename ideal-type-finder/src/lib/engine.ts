// Preference learning. Each trait option keeps a Beta(a, b) belief about
// "how likely is a face with this option to get a right swipe". Swipes
// update the beliefs; new cards come from Thompson sampling, so the deck
// starts varied and narrows toward what the user keeps liking.

import { TRAITS, allowedOptions, normalize, sameFace, type Audience, type Face, type TraitKey } from './traits';

export type Rng = () => number;

export interface Belief {
  a: number;
  b: number;
}

export type Prefs = Record<TraitKey, Record<string, Belief>>;

export type Verdict = 'like' | 'superlike' | 'nope';

export function emptyPrefs(): Prefs {
  const p = {} as Prefs;
  for (const t of TRAITS) {
    p[t.key] = {};
    for (const op of t.options) p[t.key][op.id] = { a: 1, b: 1 };
  }
  return p;
}

export function update(prefs: Prefs, face: Face, verdict: Verdict): Prefs {
  const next = {} as Prefs;
  for (const t of TRAITS) {
    next[t.key] = { ...prefs[t.key] };
    const cur = next[t.key][face[t.key]];
    if (!cur) continue;
    next[t.key][face[t.key]] =
      verdict === 'nope' ? { a: cur.a, b: cur.b + 1 } : { a: cur.a + (verdict === 'superlike' ? 2 : 1), b: cur.b };
  }
  return next;
}

export const mean = (x: Belief) => x.a / (x.a + x.b);

// Marsaglia–Tsang gamma sampler (shape >= 1, which always holds here).
function gamma(shape: number, rng: Rng): number {
  const d = shape - 1 / 3;
  const c = 1 / Math.sqrt(9 * d);
  for (;;) {
    let x: number;
    let v: number;
    do {
      // Box–Muller normal
      x = Math.sqrt(-2 * Math.log(1 - rng())) * Math.cos(2 * Math.PI * rng());
      v = 1 + c * x;
    } while (v <= 0);
    v = v * v * v;
    const u = 1 - rng();
    if (Math.log(u) < 0.5 * x * x + d - d * v + d * Math.log(v)) return d * v;
  }
}

export function sampleBeta(x: Belief, rng: Rng): number {
  const g1 = gamma(x.a, rng);
  return g1 / (g1 + gamma(x.b, rng));
}

const pick = <T,>(arr: T[], rng: Rng): T => arr[Math.floor(rng() * arr.length)];

/**
 * Draw the next card. With probability `explore` each trait is picked at
 * random; otherwise by Thompson sampling from the user's beliefs.
 */
export function generate(prefs: Prefs, audience: Audience, rng: Rng, explore: number): Face {
  const face = {} as Face;
  for (const t of TRAITS) {
    const allowed = allowedOptions(t.key, audience, face);
    if (rng() < explore) {
      face[t.key] = pick(allowed, rng);
      continue;
    }
    let best = allowed[0];
    let bestScore = -1;
    for (const id of allowed) {
      const s = sampleBeta(prefs[t.key][id], rng);
      if (s > bestScore) [best, bestScore] = [id, s];
    }
    face[t.key] = best;
  }
  return face;
}

/** Options for one trait, best first, by expected like rate. */
export function ranked(prefs: Prefs, key: TraitKey, audience: Audience, partial: Partial<Face> = {}) {
  return allowedOptions(key, audience, partial)
    .map((id) => ({ id, score: mean(prefs[key][id]), seen: prefs[key][id].a + prefs[key][id].b - 2 }))
    .sort((x, y) => y.score - x.score || y.seen - x.seen);
}

/** The single most-liked face: the top option for every trait. */
export function idealFace(prefs: Prefs, audience: Audience): Face {
  const face = {} as Face;
  for (const t of TRAITS) face[t.key] = ranked(prefs, t.key, audience, face)[0].id;
  return normalize(face, audience);
}

/**
 * Close alternatives to the ideal: swap in the runner-up on the traits
 * where the user's taste was most split. These are the "other versions"
 * of their type.
 */
export function variations(prefs: Prefs, audience: Audience, count = 3): Face[] {
  const ideal = idealFace(prefs, audience);
  const splits = TRAITS.map((t) => {
    const r = ranked(prefs, t.key, audience, ideal);
    return r.length > 1 && r[1].seen > 0 ? { key: t.key, alt: r[1].id, gap: r[0].score - r[1].score } : null;
  })
    .filter((s): s is { key: TraitKey; alt: string; gap: number } => s !== null)
    .sort((x, y) => x.gap - y.gap);

  const out: Face[] = [];
  // Each variation swaps a different pair of close-call traits.
  for (let i = 0; i < splits.length && out.length < count; i++) {
    const v = { ...ideal, [splits[i].key]: splits[i].alt };
    const second = splits[i + count];
    if (second) v[second.key] = second.alt;
    const face = normalize(v, audience);
    if (!sameFace(face, ideal) && !out.some((f) => sameFace(f, face))) out.push(face);
  }
  return out;
}

/** How sure we are about each trait, 0..1: the lead of the favourite over the runner-up. */
export function certainty(prefs: Prefs, audience: Audience): Record<TraitKey, number> {
  const out = {} as Record<TraitKey, number>;
  const ideal = idealFace(prefs, audience);
  for (const t of TRAITS) {
    const r = ranked(prefs, t.key, audience, ideal);
    out[t.key] = r.length < 2 ? 1 : Math.min(1, (r[0].score - r[1].score) * 2.5);
  }
  return out;
}

/** Log-likelihood of a like, used to seed the face-off bracket. */
export function score(prefs: Prefs, face: Face): number {
  return TRAITS.reduce((s, t) => s + Math.log(mean(prefs[t.key][face[t.key]])), 0);
}

/** Eight distinct finalists: the ideal, its variations, then strong samples. */
export function finalists(prefs: Prefs, audience: Audience, rng: Rng, size = 8): Face[] {
  const pool: Face[] = [idealFace(prefs, audience), ...variations(prefs, audience, 3)];
  for (let tries = 0; pool.length < size && tries < 400; tries++) {
    const f = normalize(generate(prefs, audience, rng, 0.05), audience);
    if (!pool.some((p) => sameFace(p, f))) pool.push(f);
  }
  // Interleave strong and weak seeds so the top two can only meet in the final.
  const sorted = [...pool].sort((x, y) => score(prefs, y) - score(prefs, x));
  const seedOrder = [0, 7, 3, 4, 1, 6, 2, 5].filter((i) => i < sorted.length);
  return seedOrder.map((i) => sorted[i]);
}

/** Small seeded RNG so the deck is reproducible in tests. */
export function mulberry32(seed: number): Rng {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Exploration schedule: fully random at first, mostly targeted by the end. */
export function exploreRate(swipeIndex: number, total: number): number {
  return Math.max(0.12, 1 - swipeIndex / (total * 0.55));
}
