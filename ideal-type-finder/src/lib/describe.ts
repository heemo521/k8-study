import { optionLabel, type Face } from './traits';

const lower = (s: string) => s.toLowerCase();

const HAIR_PHRASE: Record<string, string> = {
  buzz: 'a buzz cut',
  short: 'short hair',
  bob: 'a bob',
  long: 'long straight hair',
  wavy: 'long wavy hair',
  curly: 'curly hair',
  bun: 'hair in a top bun',
  ponytail: 'hair in a ponytail',
};

function hair(face: Face): string {
  if (face.hairStyle === 'bald') return 'a shaved head';
  const color = lower(optionLabel('hairColor', face.hairColor));
  const phrase = HAIR_PHRASE[face.hairStyle];
  // "a bob" -> "a black bob"; "short hair" -> "short black hair"
  if (phrase.startsWith('a ')) return `a ${color} ${phrase.slice(2)}`;
  if (phrase.startsWith('hair in')) return `${color} ${phrase}`;
  const [first, ...rest] = phrase.split(' ');
  return rest.length > 1 ? `${first} ${rest[0]} ${color} ${rest.slice(1).join(' ')}` : `${first} ${color} ${rest.join(' ')}`;
}

const AGE: Record<string, string> = { young: 'early twenties', adult: 'late twenties to thirties', mature: 'forties' };

/** A one-line, human description: "Long wavy auburn hair, green almond eyes, …". */
export function describe(face: Face): string {
  const parts = [
    hair(face),
    `${lower(optionLabel('eyeColor', face.eyeColor))} ${lower(optionLabel('eyeShape', face.eyeShape))} eyes`,
    `a ${lower(optionLabel('faceShape', face.faceShape))} face`,
    `${lower(optionLabel('skinTone', face.skinTone))} skin`,
    face.expression === 'smile' ? 'a warm smile' : face.expression === 'smirk' ? 'a little smirk' : 'a calm, easy look',
  ];
  if (face.facialHair !== 'none') parts.push(lower(optionLabel('facialHair', face.facialHair)));
  if (face.glasses !== 'none') parts.push(lower(optionLabel('glasses', face.glasses)));
  const text = parts.slice(0, -1).join(', ') + ' and ' + parts[parts.length - 1];
  return text.charAt(0).toUpperCase() + text.slice(1) + '.';
}

/** A prompt to paste into any image generator for a photoreal version. */
export function photoPrompt(face: Face): string {
  const who = face.presentation === 'feminine' ? 'woman' : 'man';
  const extras = [
    `${lower(optionLabel('brows', face.brows))} eyebrows`,
    `a ${lower(optionLabel('nose', face.nose))} nose`,
    `${lower(optionLabel('lips', face.lips))} lips`,
  ].join(', ');
  return (
    `Photorealistic head-and-shoulders portrait of a ${who} in their ${AGE[face.age]}, with ` +
    describe(face).replace(/\.$/, '').replace(/^./, (c) => c.toLowerCase()) +
    `, ${extras}. Soft natural window light, 85mm lens, shallow depth of field, plain background, candid and friendly.`
  );
}
