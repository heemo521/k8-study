import { describe as suite, expect, it } from 'vitest';
import { emptyPrefs, finalists, generate, idealFace, mulberry32, update, variations } from './engine';
import { TRAITS, decodeFace, encodeFace, sameFace, type Face } from './traits';
import { describe, photoPrompt } from './describe';

// A simulated user who likes one hair style + eye color and nothing else.
const likes = (f: Face) => f.hairStyle === 'wavy' && f.eyeColor === 'green';

suite('preference engine', () => {
  it('learns a target type from simulated swipes', () => {
    const rng = mulberry32(42);
    let prefs = emptyPrefs();
    for (let i = 0; i < 300; i++) {
      const f = generate(prefs, 'women', rng, i < 120 ? 1 : 0.2);
      prefs = update(prefs, f, likes(f) ? 'like' : 'nope');
    }
    const ideal = idealFace(prefs, 'women');
    expect(ideal.hairStyle).toBe('wavy');
    expect(ideal.eyeColor).toBe('green');
    expect(ideal.presentation).toBe('feminine');
  });

  it('never gives feminine faces facial hair', () => {
    const rng = mulberry32(7);
    for (let i = 0; i < 200; i++) {
      const f = generate(emptyPrefs(), 'everyone', rng, 1);
      if (f.presentation === 'feminine') expect(f.facialHair).toBe('none');
    }
  });

  it('respects the audience choice', () => {
    const rng = mulberry32(1);
    for (let i = 0; i < 50; i++) expect(generate(emptyPrefs(), 'men', rng, 1).presentation).toBe('masculine');
  });

  it('builds eight distinct finalists and distinct variations', () => {
    const rng = mulberry32(3);
    let prefs = emptyPrefs();
    for (let i = 0; i < 40; i++) {
      const f = generate(prefs, 'everyone', rng, 1);
      prefs = update(prefs, f, i % 3 ? 'like' : 'nope');
    }
    const fs = finalists(prefs, 'everyone', rng);
    expect(fs).toHaveLength(8);
    fs.forEach((a, i) => fs.slice(i + 1).forEach((b) => expect(sameFace(a, b)).toBe(false)));
    const ideal = idealFace(prefs, 'everyone');
    for (const v of variations(prefs, 'everyone')) expect(sameFace(v, ideal)).toBe(false);
  });
});

suite('share codes and text', () => {
  it('round-trips every face through a share code', () => {
    const rng = mulberry32(9);
    for (let i = 0; i < 100; i++) {
      const f = generate(emptyPrefs(), 'everyone', rng, 1);
      const code = encodeFace(f);
      expect(code).toHaveLength(TRAITS.length);
      expect(decodeFace(code)).toEqual(f);
    }
  });

  it('rejects malformed codes', () => {
    expect(decodeFace('zz')).toBeNull();
    expect(decodeFace('z'.repeat(TRAITS.length))).toBeNull();
    expect(decodeFace('<script>')).toBeNull();
  });

  it('describes a face in plain words', () => {
    const f = decodeFace('0' + '1'.repeat(TRAITS.length - 1))!;
    expect(describe(f)).toMatch(/^[A-Z].*\.$/);
    expect(photoPrompt(f)).toContain('Photorealistic');
  });
});
