import { useEffect, useMemo, useRef, useState } from 'react';
import FaceSvg from './components/FaceSvg';
import SwipeDeck from './components/SwipeDeck';
import FaceOff from './components/FaceOff';
import Result from './components/Result';
import Board from './components/Board';
import { describe } from './lib/describe';
import {
  certainty,
  emptyPrefs,
  exploreRate,
  finalists,
  generate,
  mulberry32,
  update,
  variations,
  type Prefs,
  type Verdict,
} from './lib/engine';
import { decodeFace, encodeFace, normalize, sameFace, similarity, type Audience, type Face, type TraitKey } from './lib/traits';
import { load, save, type Post, type Saved } from './lib/storage';

type Screen = 'home' | 'swipe' | 'faceoff' | 'result' | 'board' | 'shared';

interface Deck {
  prefs: Prefs;
  face: Face;
  next: Face;
  index: number;
  likes: number;
}

interface Outcome {
  champion: Face;
  versions: Face[];
  certainty: Record<TraitKey, number>;
  swipes: number;
  likes: number;
}

const LENGTHS = [
  { n: 20, label: 'Quick', detail: '20 swipes' },
  { n: 40, label: 'Standard', detail: '40 swipes' },
  { n: 60, label: 'Deep', detail: '60 swipes' },
];

const AUDIENCES: { id: Audience; label: string }[] = [
  { id: 'women', label: 'Women' },
  { id: 'men', label: 'Men' },
  { id: 'everyone', label: 'Everyone' },
];

// Example faces for the home screen fan, drawn from fixed seeds.
const SHOWCASE = [3, 7, 11, 19].map((seed) => normalize(generate(emptyPrefs(), 'everyone', mulberry32(seed), 1), 'everyone'));

function sharedCodeFromHash(): string | null {
  const m = /^#t-([0-9a-z]+)$/.exec(window.location.hash);
  return m && decodeFace(m[1]) ? m[1] : null;
}

export default function App() {
  const [screen, setScreen] = useState<Screen>(() => (sharedCodeFromHash() ? 'shared' : 'home'));
  const [audience, setAudience] = useState<Audience>('everyone');
  const [total, setTotal] = useState(40);
  const [deck, setDeck] = useState<Deck | null>(null);
  const [history, setHistory] = useState<Deck[]>([]);
  const [seeds, setSeeds] = useState<Face[]>([]);
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [saved, setSaved] = useState<Saved>(() => load());
  const [draft, setDraft] = useState<Face | null>(null);
  const [sharedCode, setSharedCode] = useState<string | null>(() => sharedCodeFromHash());
  const rng = useRef(mulberry32(Date.now() & 0xffffffff));

  useEffect(() => save(saved), [saved]);
  useEffect(() => window.scrollTo({ top: 0 }), [screen]);
  useEffect(() => {
    const onHash = () => {
      const code = sharedCodeFromHash();
      if (code) {
        setSharedCode(code);
        setScreen('shared');
      }
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const myType = useMemo(() => (saved.lastTypeCode ? decodeFace(saved.lastTypeCode) : null), [saved.lastTypeCode]);
  const draw = (prefs: Prefs, i: number) => normalize(generate(prefs, audience, rng.current, exploreRate(i, total)), audience);

  const start = () => {
    const prefs = emptyPrefs();
    setDeck({ prefs, face: draw(prefs, 0), next: draw(prefs, 1), index: 0, likes: 0 });
    setHistory([]);
    setOutcome(null);
    setScreen('swipe');
  };

  const onVerdict = (v: Verdict) => {
    if (!deck) return;
    const prefs = update(deck.prefs, deck.face, v);
    const index = deck.index + 1;
    const likes = deck.likes + (v === 'nope' ? 0 : 1);
    setHistory((h) => [...h, deck]);
    if (index >= total) {
      setDeck({ ...deck, prefs, index, likes });
      setSeeds(finalists(prefs, audience, rng.current));
      setScreen('faceoff');
      return;
    }
    // The card shown underneath becomes the top card; draw a fresh one under it.
    let next = draw(prefs, index + 1);
    for (let i = 0; i < 5 && sameFace(next, deck.next); i++) next = draw(prefs, index + 1);
    setDeck({ prefs, face: deck.next, next, index, likes });
  };

  const undo = () => {
    const prev = history[history.length - 1];
    if (!prev) return;
    setHistory((h) => h.slice(0, -1));
    setDeck(prev);
  };

  const onPick = (winner: Face, loser: Face) => {
    setDeck((d) => (d ? { ...d, prefs: update(update(d.prefs, winner, 'like'), loser, 'nope') } : d));
  };

  const onDone = (champion: Face, runnersUp: Face[]) => {
    const prefs = deck!.prefs;
    const versions: Face[] = [];
    for (const f of [...runnersUp.slice(0, 2), ...variations(prefs, audience, 4)]) {
      if (versions.length < 4 && !sameFace(f, champion) && !versions.some((v) => sameFace(v, f))) versions.push(f);
    }
    setOutcome({ champion, versions, certainty: certainty(prefs, audience), swipes: total, likes: deck!.likes });
    setSaved((s) => ({ ...s, lastTypeCode: encodeFace(champion) }));
    setScreen('result');
  };

  // A <meta name="share-base"> overrides the page URL when the app is
  // embedded somewhere whose own address isn't the one to share.
  const shareBase = document.querySelector<HTMLMetaElement>('meta[name="share-base"]')?.content || window.location.href.split('#')[0];
  const shareUrl = (f: Face) => `${shareBase}#t-${encodeFace(f)}`;

  const goHome = () => {
    if (window.location.hash) clearHash();
    setScreen('home');
  };

  const sharedFace = sharedCode ? decodeFace(sharedCode) : null;

  return (
    <div className="app">
      <header className="topbar">
        <button className="brand" onClick={goHome}>
          <span className="brand-mark" aria-hidden="true">
            ♥
          </span>
          Ideal Type
        </button>
        <nav className="nav">
          {outcome && screen !== 'result' && (
            <button className="link-btn" onClick={() => setScreen('result')}>
              My type
            </button>
          )}
          <button className="link-btn" onClick={() => setScreen('board')}>
            Looking for
          </button>
        </nav>
      </header>

      <main className="main">
        {screen === 'home' && (
          <div className="home">
            <div className="fan" aria-hidden="true">
              {SHOWCASE.map((f, i) => (
                <div key={i} className={`fan-card fan-${i}`}>
                  <FaceSvg face={f} className="card-face" />
                </div>
              ))}
            </div>
            <div className="home-copy">
              <h1 className="display">Swipe until you find your type.</h1>
              <p className="lede">
                Every face here is generated. Swipe right on the ones you like and left on the ones you don't. The deck learns as you go, then a
                short face-off picks the winner.
              </p>

              <fieldset className="choice">
                <legend>Show me</legend>
                <div className="segmented">
                  {AUDIENCES.map((a) => (
                    <label key={a.id} className={audience === a.id ? 'on' : ''}>
                      <input type="radio" name="audience" id={`aud-${a.id}`} checked={audience === a.id} onChange={() => setAudience(a.id)} />
                      {a.label}
                    </label>
                  ))}
                </div>
              </fieldset>

              <fieldset className="choice">
                <legend>How long</legend>
                <div className="segmented">
                  {LENGTHS.map((l) => (
                    <label key={l.n} className={total === l.n ? 'on' : ''}>
                      <input type="radio" name="length" id={`len-${l.n}`} checked={total === l.n} onChange={() => setTotal(l.n)} />
                      {l.label}
                      <small>{l.detail}</small>
                    </label>
                  ))}
                </div>
              </fieldset>

              <button className="btn primary big" onClick={start}>
                Start swiping
              </button>
              <ol className="steps">
                <li>
                  <strong>Swipe</strong> {total} faces. Early cards are random; later ones lean toward what you liked.
                </li>
                <li>
                  <strong>Face-off.</strong> Eight finalists, pick one of two until one is left.
                </li>
                <li>
                  <strong>Post it.</strong> Share your type, or post “I'm looking for this one.”
                </li>
              </ol>
            </div>
          </div>
        )}

        {screen === 'swipe' && deck && (
          <SwipeDeck face={deck.face} next={deck.next} index={deck.index} total={total} onVerdict={onVerdict} onUndo={history.length ? undo : undefined} />
        )}

        {screen === 'faceoff' && seeds.length >= 2 && <FaceOff seeds={seeds} onPick={onPick} onDone={onDone} />}

        {screen === 'result' && outcome && (
          <Result
            {...outcome}
            shareUrl={shareUrl}
            onPost={(f) => {
              setDraft(f);
              setScreen('board');
            }}
            onRestart={start}
          />
        )}

        {screen === 'board' && (
          <Board
            posts={saved.posts}
            draft={draft ?? myType}
            myType={myType}
            onCreate={(p: Post) => setSaved((s) => ({ ...s, posts: [p, ...s.posts] }))}
            onDelete={(id) => setSaved((s) => ({ ...s, posts: s.posts.filter((p) => p.id !== id) }))}
            onOpen={(code) => {
              setSharedCode(code);
              setScreen('shared');
            }}
            onFind={() => setScreen('home')}
          />
        )}

        {screen === 'shared' && sharedFace && (
          <div className="shared">
            <p className="eyebrow">Someone's ideal type</p>
            <FaceSvg face={sharedFace} className="result-face" title="Shared ideal type" />
            <p className="result-desc">{describe(sharedFace)}</p>
            {myType && <p className="chip big-chip">{Math.round(similarity(myType, sharedFace) * 100)}% like your type</p>}
            <button className="btn primary" onClick={goHome}>
              Find your own type
            </button>
          </div>
        )}
      </main>
    </div>
  );
}

function clearHash() {
  try {
    window.history.replaceState(null, '', window.location.pathname + window.location.search);
  } catch {
    /* sandboxed frames may refuse */
  }
}
