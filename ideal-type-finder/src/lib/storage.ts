// Everything is kept in this browser only. Storage can be blocked (private
// windows, embedded previews), so every access is guarded and the app
// works without it.

const KEY = 'ideal-type-finder:v1';

export interface Post {
  id: string;
  handle: string;
  note: string;
  code: string;
  createdAt: number;
}

export interface Saved {
  posts: Post[];
  lastTypeCode?: string;
}

export function load(): Saved {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const data = JSON.parse(raw) as Saved;
      return { posts: Array.isArray(data.posts) ? data.posts : [], lastTypeCode: data.lastTypeCode };
    }
  } catch {
    /* storage unavailable */
  }
  return { posts: [] };
}

export function save(data: Saved): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(data));
  } catch {
    /* storage unavailable */
  }
}
