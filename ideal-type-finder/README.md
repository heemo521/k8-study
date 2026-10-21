# Ideal Type Finder

Swipe through generated faces to find your ideal type, then post
“I'm looking for this one.”

## How it works

1. **Swipe.** Pick who you want to see (women, men, everyone) and a length
   (20 / 40 / 60 swipes). Swipe right (♥), left (✕) or up (★ “Wow”), or use
   the arrow keys. Undo is available.
2. **The deck learns.** Every face is built from 14 traits (face shape, skin
   tone, hair style and color, eye shape and color, brows, nose, lips, vibe,
   age, facial hair, glasses). Each trait option keeps a Beta belief of how
   often you like it. Early cards are random; later cards are drawn by
   Thompson sampling, so they lean toward what you keep liking while still
   testing close calls.
3. **Face-off.** Eight finalists (your top-scoring face, close variations,
   and strong samples) go into a bracket. Pick one of two until one is left.
4. **Your type.** The champion, up to four other versions of your type,
   a plain-English description, and a per-trait breakdown of how strongly
   your swipes agreed.
5. **Share / post.** Copy a share link (`#t-<code>`; 14 characters encode the
   whole face), copy a prompt for any AI image generator to get a
   photorealistic version, or post “I'm looking for this” with your handle
   and a note.

Faces are drawn as SVG from their traits, so the same traits always give the
same face and nothing is sent to a server. Posts and your last type are saved
in this browser's localStorage only.

## Develop

```bash
npm install
npm run dev          # http://localhost:5173
npm test             # engine + renderer tests (vitest)
npm run build        # type-check + static build in dist/
npm run build:single # also writes dist/single.html, one self-contained file
```

The build uses a relative base, so `dist/` can be served from any static
host or subfolder. This folder is self-contained and can be moved into its
own repository as is.

## Code map

| Path | What it does |
| --- | --- |
| `src/lib/traits.ts` | Trait space, audience rules, share-code encode/decode |
| `src/lib/engine.ts` | Beta beliefs, Thompson sampling, ideal face, variations, finalists |
| `src/lib/describe.ts` | Plain-English description and AI photo prompt |
| `src/components/FaceSvg.tsx` | Procedural face renderer |
| `src/components/SwipeDeck.tsx` | Drag/keyboard swipe card stack |
| `src/components/FaceOff.tsx` | 8-face single-elimination bracket |
| `src/components/Result.tsx` | Your type, versions, trait breakdown, share |
| `src/components/Board.tsx` | “Looking for” posts |

## Next steps

- **Shared board.** Posts are local to one browser today. A small backend
  (e.g. Supabase or Firebase) would let people browse each other's posts and
  match on similar types (`similarity()` already scores trait overlap).
- **Photoreal faces.** Swap or augment `FaceSvg` with an image-generation API
  using `photoPrompt()`; cache images by share code.
- **Smarter learning.** Model trait interactions (e.g. hair color × skin tone)
  instead of treating traits independently.
