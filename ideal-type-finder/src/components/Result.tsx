import { useState } from 'react';
import FaceSvg from './FaceSvg';
import { describe, photoPrompt } from '../lib/describe';
import { TRAITS, optionLabel, type Face, type TraitKey } from '../lib/traits';

interface Props {
  champion: Face;
  versions: Face[];
  certainty: Record<TraitKey, number>;
  swipes: number;
  likes: number;
  shareUrl: (f: Face) => string;
  onPost: (f: Face) => void;
  onRestart: () => void;
}

// Traits that read as "who they are" lead the breakdown; presentation is
// usually fixed by the audience choice, so it's left out.
const SHOWN: TraitKey[] = TRAITS.map((t) => t.key).filter((k) => k !== 'presentation');

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

export default function Result({ champion, versions, certainty, swipes, likes, shareUrl, onPost, onRestart }: Props) {
  const [selected, setSelected] = useState<Face>(champion);
  const [copied, setCopied] = useState<string | null>(null);
  const [fallback, setFallback] = useState<string | null>(null);
  const all = [champion, ...versions];

  const copy = async (label: string, text: string) => {
    if (await copyText(text)) {
      setCopied(label);
      setFallback(null);
      window.setTimeout(() => setCopied(null), 1800);
    } else {
      setFallback(text);
    }
  };

  return (
    <div className="result">
      <p className="eyebrow">
        Your ideal type · from {swipes} swipes, {likes} liked
      </p>
      <div className="result-hero">
        <FaceSvg face={selected} className="result-face" title="Your ideal type" />
        <div className="result-copy">
          <h2 className="screen-title">{selected === champion ? 'This is your type.' : 'Another version of your type.'}</h2>
          <p className="result-desc">{describe(selected)}</p>
          <div className="result-actions">
            <button className="btn primary" onClick={() => onPost(selected)}>
              Post “I'm looking for this”
            </button>
            <button className="btn" onClick={() => copy('link', shareUrl(selected))}>
              {copied === 'link' ? 'Link copied' : 'Copy share link'}
            </button>
            <button className="btn" onClick={() => copy('prompt', photoPrompt(selected))}>
              {copied === 'prompt' ? 'Prompt copied' : 'Copy AI photo prompt'}
            </button>
          </div>
          {fallback && (
            <textarea
              id="copy-fallback"
              className="copy-fallback"
              readOnly
              value={fallback}
              onFocus={(e) => e.currentTarget.select()}
              aria-label="Text to copy"
            />
          )}
        </div>
      </div>

      <section className="section">
        <h3 className="section-title">Versions of your type</h3>
        <div className="versions">
          {all.map((f, i) => (
            <button key={i} className={`version ${f === selected ? 'active' : ''}`} onClick={() => setSelected(f)}>
              <FaceSvg face={f} className="version-face" title={i === 0 ? 'Champion' : `Version ${i + 1}`} />
              <span>{i === 0 ? 'Champion' : `Version ${i + 1}`}</span>
            </button>
          ))}
        </div>
      </section>

      <section className="section">
        <h3 className="section-title">What you went for</h3>
        <dl className="traits">
          {SHOWN.map((k) => (
            <div key={k} className="trait-row">
              <dt>{TRAITS.find((t) => t.key === k)!.label}</dt>
              <dd>
                <span className="trait-value">{optionLabel(k, champion[k])}</span>
                <span className="meter" aria-label={`${Math.round(certainty[k] * 100)}% sure`}>
                  <span style={{ width: `${Math.max(6, certainty[k] * 100)}%` }} />
                </span>
              </dd>
            </div>
          ))}
        </dl>
        <p className="fine">Bars show how strongly your swipes agreed on each trait. Short bars mean you're open on that one.</p>
      </section>

      <button className="btn ghost" onClick={onRestart}>
        Swipe again
      </button>
    </div>
  );
}
