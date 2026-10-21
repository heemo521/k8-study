import { expect, it } from 'vitest';
import { renderToString } from 'react-dom/server';
import FaceSvg from './FaceSvg';
import { emptyPrefs, generate, mulberry32 } from '../lib/engine';

it('renders a wide sample of faces without errors or NaN coordinates', () => {
  const rng = mulberry32(2024);
  for (let i = 0; i < 400; i++) {
    const face = generate(emptyPrefs(), 'everyone', rng, 1);
    const svg = renderToString(<FaceSvg face={face} />);
    expect(svg).not.toMatch(/NaN|undefined/);
  }
});
