import { useState } from 'react';
import FaceSvg from './FaceSvg';
import { describe } from '../lib/describe';
import { decodeFace, encodeFace, similarity, type Face } from '../lib/traits';
import type { Post } from '../lib/storage';

interface Props {
  posts: Post[];
  draft: Face | null;
  myType: Face | null;
  onCreate: (p: Post) => void;
  onDelete: (id: string) => void;
  onOpen: (code: string) => void;
  onFind: () => void;
}

export default function Board({ posts, draft, myType, onCreate, onDelete, onOpen, onFind }: Props) {
  const [handle, setHandle] = useState('');
  const [note, setNote] = useState('');

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!draft || !handle.trim()) return;
    onCreate({
      id: Math.random().toString(36).slice(2, 10),
      handle: handle.trim().replace(/^@?/, '@'),
      note: note.trim(),
      code: encodeFace(draft),
      createdAt: Date.now(),
    });
    setNote('');
  };

  return (
    <div className="board">
      <p className="eyebrow">Looking for</p>
      <h2 className="screen-title">“I'm looking for this one.”</h2>

      {draft ? (
        <form className="post-form" onSubmit={submit}>
          <FaceSvg face={draft} className="post-form-face" title="Type you're posting" />
          <div className="post-form-fields">
            <p className="result-desc">{describe(draft)}</p>
            <label htmlFor="post-handle">Your name or handle</label>
            <input id="post-handle" value={handle} onChange={(e) => setHandle(e.target.value)} placeholder="@yourname" maxLength={30} required />
            <label htmlFor="post-note">A line about what you're after</label>
            <textarea
              id="post-note"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Coffee dates, bad puns, and someone who looks like this."
              maxLength={160}
              rows={3}
            />
            <button className="btn primary" type="submit" disabled={!handle.trim()}>
              Post it
            </button>
          </div>
        </form>
      ) : (
        <div className="empty">
          <p>Find your type first, then post it here.</p>
          <button className="btn primary" onClick={onFind}>
            Start swiping
          </button>
        </div>
      )}

      <section className="section">
        <h3 className="section-title">Posts on this device</h3>
        {posts.length === 0 ? (
          <p className="fine">No posts yet. Your posts are saved in this browser. Use “Copy share link” on a post to send it to someone.</p>
        ) : (
          <ul className="posts">
            {posts.map((p) => {
              const face = decodeFace(p.code);
              if (!face) return null;
              const match = myType ? Math.round(similarity(myType, face) * 100) : null;
              return (
                <li key={p.id} className="post">
                  <button className="post-face-btn" onClick={() => onOpen(p.code)} aria-label={`Open ${p.handle}'s type`}>
                    <FaceSvg face={face} className="post-face" />
                  </button>
                  <div className="post-body">
                    <div className="post-head">
                      <strong>{p.handle}</strong>
                      <span className="fine">is looking for</span>
                      {match !== null && <span className="chip">{match}% like your type</span>}
                    </div>
                    <p className="post-desc">{describe(face)}</p>
                    {p.note && <p className="post-note">“{p.note}”</p>}
                    <div className="post-actions">
                      <button className="link-btn" onClick={() => onOpen(p.code)}>
                        Open
                      </button>
                      <button className="link-btn" onClick={() => onDelete(p.id)}>
                        Delete
                      </button>
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}
