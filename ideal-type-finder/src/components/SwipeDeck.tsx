import { useEffect, useRef, useState } from 'react';
import FaceSvg from './FaceSvg';
import type { Face } from '../lib/traits';
import type { Verdict } from '../lib/engine';

interface Props {
  face: Face;
  next: Face;
  index: number;
  total: number;
  onVerdict: (v: Verdict) => void;
  onUndo?: () => void;
}

const THRESHOLD = 90;

export default function SwipeDeck({ face, next, index, total, onVerdict, onUndo }: Props) {
  const [drag, setDrag] = useState({ x: 0, y: 0 });
  const [leaving, setLeaving] = useState<Verdict | null>(null);
  const start = useRef<{ x: number; y: number } | null>(null);

  // Reset position whenever a new card arrives.
  useEffect(() => {
    setDrag({ x: 0, y: 0 });
    setLeaving(null);
  }, [face]);

  const decide = (v: Verdict) => {
    if (leaving) return;
    setLeaving(v);
    window.setTimeout(() => onVerdict(v), 220);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key === 'ArrowRight') decide('like');
      else if (e.key === 'ArrowLeft') decide('nope');
      else if (e.key === 'ArrowUp') decide('superlike');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const onDown = (e: React.PointerEvent) => {
    if (leaving) return;
    (e.target as Element).setPointerCapture?.(e.pointerId);
    start.current = { x: e.clientX, y: e.clientY };
  };
  const onMove = (e: React.PointerEvent) => {
    if (!start.current) return;
    setDrag({ x: e.clientX - start.current.x, y: e.clientY - start.current.y });
  };
  const onUp = () => {
    if (!start.current) return;
    start.current = null;
    if (drag.y < -THRESHOLD && Math.abs(drag.x) < THRESHOLD) decide('superlike');
    else if (drag.x > THRESHOLD) decide('like');
    else if (drag.x < -THRESHOLD) decide('nope');
    else setDrag({ x: 0, y: 0 });
  };

  let x = drag.x;
  let y = drag.y;
  if (leaving === 'like') x = 600;
  if (leaving === 'nope') x = -600;
  if (leaving === 'superlike') y = -700;
  const rot = x / 18;
  const likeO = Math.max(0, Math.min(1, drag.x / THRESHOLD)) || (leaving === 'like' ? 1 : 0);
  const nopeO = Math.max(0, Math.min(1, -drag.x / THRESHOLD)) || (leaving === 'nope' ? 1 : 0);
  const superO = Math.max(0, Math.min(1, -drag.y / THRESHOLD)) || (leaving === 'superlike' ? 1 : 0);
  const dragging = start.current !== null;

  return (
    <div className="deck">
      <div className="deck-progress" aria-label={`Card ${index + 1} of ${total}`}>
        <div className="deck-progress-bar" style={{ width: `${(index / total) * 100}%` }} />
      </div>
      <div className="deck-meta">
        <span>
          {index + 1} / {total}
        </span>
        <span>{index < total * 0.4 ? 'Exploring' : 'Narrowing down'}</span>
      </div>

      <div className="deck-stack">
        <div className="card card-under" aria-hidden="true">
          <FaceSvg face={next} className="card-face" />
        </div>
        <div
          className="card card-top"
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          style={{
            transform: `translate(${x}px, ${y}px) rotate(${rot}deg)`,
            transition: dragging ? 'none' : 'transform 220ms ease-out',
          }}
        >
          <FaceSvg face={face} className="card-face" title="Candidate face" />
          <span className="stamp stamp-like" style={{ opacity: likeO }}>
            Into it
          </span>
          <span className="stamp stamp-nope" style={{ opacity: nopeO }}>
            Pass
          </span>
          <span className="stamp stamp-super" style={{ opacity: superO }}>
            Wow
          </span>
        </div>
      </div>

      <div className="deck-actions">
        <button className="round-btn nope" onClick={() => decide('nope')} aria-label="Pass (left arrow)">
          ✕
        </button>
        <button className="round-btn super" onClick={() => decide('superlike')} aria-label="Wow (up arrow)">
          ★
        </button>
        <button className="round-btn like" onClick={() => decide('like')} aria-label="Into it (right arrow)">
          ♥
        </button>
      </div>
      <p className="hint">
        Swipe or use ← ↑ → keys.{' '}
        {onUndo && (
          <button className="link-btn" onClick={onUndo}>
            Undo last
          </button>
        )}
      </p>
    </div>
  );
}
