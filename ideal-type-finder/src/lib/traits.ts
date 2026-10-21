// The trait space every generated face is drawn from. Order matters:
// share codes store one option index per trait, in this order.

export interface Option {
  id: string;
  label: string;
}

export interface TraitDef {
  key: TraitKey;
  label: string;
  options: Option[];
}

export type TraitKey =
  | 'presentation'
  | 'age'
  | 'faceShape'
  | 'skinTone'
  | 'hairStyle'
  | 'hairColor'
  | 'eyeShape'
  | 'eyeColor'
  | 'brows'
  | 'nose'
  | 'lips'
  | 'expression'
  | 'facialHair'
  | 'glasses';

export type Face = Record<TraitKey, string>;

const o = (id: string, label: string): Option => ({ id, label });

export const TRAITS: TraitDef[] = [
  { key: 'presentation', label: 'Presentation', options: [o('feminine', 'Feminine'), o('masculine', 'Masculine')] },
  { key: 'age', label: 'Age', options: [o('young', 'Early 20s'), o('adult', 'Late 20s–30s'), o('mature', '40s+')] },
  {
    key: 'faceShape',
    label: 'Face shape',
    options: [o('oval', 'Oval'), o('round', 'Round'), o('square', 'Square'), o('heart', 'Heart'), o('long', 'Long')],
  },
  {
    key: 'skinTone',
    label: 'Skin tone',
    options: [o('porcelain', 'Porcelain'), o('fair', 'Fair'), o('olive', 'Olive'), o('tan', 'Tan'), o('brown', 'Brown'), o('deep', 'Deep')],
  },
  {
    key: 'hairStyle',
    label: 'Hair',
    options: [
      o('buzz', 'Buzz cut'),
      o('short', 'Short'),
      o('bob', 'Bob'),
      o('long', 'Long & straight'),
      o('wavy', 'Long & wavy'),
      o('curly', 'Curly'),
      o('bun', 'Top bun'),
      o('ponytail', 'Ponytail'),
      o('bald', 'Bald'),
    ],
  },
  {
    key: 'hairColor',
    label: 'Hair color',
    options: [
      o('black', 'Black'),
      o('darkbrown', 'Dark brown'),
      o('brown', 'Brown'),
      o('auburn', 'Auburn'),
      o('blonde', 'Blonde'),
      o('platinum', 'Platinum'),
      o('red', 'Red'),
      o('silver', 'Silver'),
    ],
  },
  { key: 'eyeShape', label: 'Eye shape', options: [o('almond', 'Almond'), o('round', 'Round'), o('hooded', 'Hooded'), o('monolid', 'Monolid')] },
  {
    key: 'eyeColor',
    label: 'Eye color',
    options: [o('brown', 'Brown'), o('hazel', 'Hazel'), o('green', 'Green'), o('blue', 'Blue'), o('gray', 'Gray')],
  },
  { key: 'brows', label: 'Brows', options: [o('thin', 'Thin'), o('natural', 'Natural'), o('bold', 'Bold')] },
  { key: 'nose', label: 'Nose', options: [o('button', 'Button'), o('straight', 'Straight'), o('wide', 'Wide'), o('roman', 'Roman')] },
  { key: 'lips', label: 'Lips', options: [o('thin', 'Thin'), o('medium', 'Medium'), o('full', 'Full')] },
  { key: 'expression', label: 'Vibe', options: [o('smile', 'Warm smile'), o('smirk', 'Smirk'), o('calm', 'Calm')] },
  {
    key: 'facialHair',
    label: 'Facial hair',
    options: [o('none', 'Clean-shaven'), o('stubble', 'Stubble'), o('mustache', 'Mustache'), o('beard', 'Full beard')],
  },
  { key: 'glasses', label: 'Glasses', options: [o('none', 'No glasses'), o('round', 'Round frames'), o('square', 'Square frames')] },
];

export const TRAIT_BY_KEY = Object.fromEntries(TRAITS.map((t) => [t.key, t])) as Record<TraitKey, TraitDef>;

export function optionLabel(key: TraitKey, id: string): string {
  return TRAIT_BY_KEY[key].options.find((op) => op.id === id)?.label ?? id;
}

export type Audience = 'women' | 'men' | 'everyone';

/** Options a face may take for a trait, given who the user wants to see and the face so far. */
export function allowedOptions(key: TraitKey, audience: Audience, partial: Partial<Face>): string[] {
  const all = TRAIT_BY_KEY[key].options.map((op) => op.id);
  if (key === 'presentation') {
    if (audience === 'women') return ['feminine'];
    if (audience === 'men') return ['masculine'];
    return all;
  }
  if (key === 'facialHair' && partial.presentation === 'feminine') return ['none'];
  return all;
}

/** Fix any combination the renderer or audience can't show. */
export function normalize(face: Face, audience: Audience): Face {
  const out = { ...face };
  for (const t of TRAITS) {
    const allowed = allowedOptions(t.key, audience, out);
    if (!allowed.includes(out[t.key])) out[t.key] = allowed[0];
  }
  return out;
}

// ---- Share codes: one base-36 digit per trait, e.g. "0102340211020". ----

export function encodeFace(face: Face): string {
  return TRAITS.map((t) => Math.max(0, t.options.findIndex((op) => op.id === face[t.key])).toString(36)).join('');
}

export function decodeFace(code: string): Face | null {
  if (!/^[0-9a-z]+$/.test(code) || code.length !== TRAITS.length) return null;
  const face = {} as Face;
  for (let i = 0; i < TRAITS.length; i++) {
    const op = TRAITS[i].options[parseInt(code[i], 36)];
    if (!op) return null;
    face[TRAITS[i].key] = op.id;
  }
  return face;
}

export function sameFace(a: Face, b: Face): boolean {
  return TRAITS.every((t) => a[t.key] === b[t.key]);
}

/** Share of traits two faces have in common, 0..1. */
export function similarity(a: Face, b: Face): number {
  return TRAITS.filter((t) => a[t.key] === b[t.key]).length / TRAITS.length;
}
