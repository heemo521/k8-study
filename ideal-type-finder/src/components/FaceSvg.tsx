import { useId } from 'react';
import { encodeFace, type Face } from '../lib/traits';

// Procedural portrait. Every face is drawn from its traits alone, so the
// same traits always produce the same picture and share codes stay tiny.

const SKIN: Record<string, string> = {
  porcelain: '#F6E0D2',
  fair: '#EDC6A8',
  olive: '#D3A77B',
  tan: '#BF885A',
  brown: '#8C5939',
  deep: '#5B3826',
};
const HAIR: Record<string, string> = {
  black: '#1F1B1D',
  darkbrown: '#3C2A20',
  brown: '#6A452E',
  auburn: '#8C3A1F',
  blonde: '#D8B068',
  platinum: '#E9E2CF',
  red: '#B4462A',
  silver: '#B8B8BE',
};
const IRIS: Record<string, string> = {
  brown: '#5A381F',
  hazel: '#8A6A2E',
  green: '#4C7C48',
  blue: '#4A7AB6',
  gray: '#7B8993',
};
const BACKDROPS = ['#F3D9D3', '#D9E6DA', '#D8DFEE', '#EFE3C8', '#E6D6EA', '#CFE5E6'];
const SHIRTS = ['#2F3E5C', '#7A2E3B', '#3F5B45', '#C9A15B', '#5B4B73', '#E8E2D6', '#2B2B2B'];

interface Shape {
  w: number;
  jw: number;
  cheekY: number;
  jawY: number;
  chinY: number;
}
const SHAPES: Record<string, Shape> = {
  oval: { w: 124, jw: 84, cheekY: 140, jawY: 192, chinY: 222 },
  round: { w: 132, jw: 104, cheekY: 140, jawY: 188, chinY: 214 },
  square: { w: 124, jw: 110, cheekY: 140, jawY: 200, chinY: 216 },
  heart: { w: 130, jw: 70, cheekY: 136, jawY: 188, chinY: 222 },
  long: { w: 114, jw: 86, cheekY: 140, jawY: 202, chinY: 230 },
};

const CX = 120;
const TOP = 62;

function hex(c: string): [number, number, number] {
  const n = parseInt(c.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function mix(a: string, b: string, t: number): string {
  const [r1, g1, b1] = hex(a);
  const [r2, g2, b2] = hex(b);
  const m = (x: number, y: number) => Math.round(x + (y - x) * t);
  return '#' + [m(r1, r2), m(g1, g2), m(b1, b2)].map((v) => v.toString(16).padStart(2, '0')).join('');
}
const darken = (c: string, t: number) => mix(c, '#1a0f0a', t);

function hash(s: string): number {
  let h = 7;
  for (const ch of s) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h;
}

export default function FaceSvg({ face, className, title }: { face: Face; className?: string; title?: string }) {
  const uid = useId().replace(/[^a-zA-Z0-9]/g, '');
  const masc = face.presentation === 'masculine';
  const base = SHAPES[face.faceShape] ?? SHAPES.oval;
  const s: Shape = masc ? { ...base, w: base.w + 4, jw: Math.min(base.jw + 12, base.w) } : base;
  const { w, jw, cheekY, jawY, chinY } = s;
  const L = CX - w / 2;
  const R = CX + w / 2;

  const skin = SKIN[face.skinTone];
  const shade = darken(skin, 0.18);
  const line = darken(skin, 0.42);
  let hairC = HAIR[face.hairColor];
  if (face.age === 'mature' && face.hairColor !== 'silver') hairC = mix(hairC, '#B8B8BE', 0.3);
  const browC = ['blonde', 'platinum', 'silver'].includes(face.hairColor) ? darken(hairC, 0.35) : hairC;
  const lip = mix(skin, '#B04A55', masc ? 0.22 : 0.45);

  const h = hash(encodeFace(face));
  const backdrop = BACKDROPS[h % BACKDROPS.length];
  const shirt = SHIRTS[(h >>> 4) % SHIRTS.length];

  const eyeY = cheekY - 4;
  const noseY = eyeY + 34;
  const mouthY = noseY + (chinY - noseY) * 0.4;

  const head =
    `M ${CX} ${TOP} C ${CX + w * 0.3} ${TOP}, ${R} ${TOP + 28}, ${R} ${cheekY} ` +
    `C ${R} ${cheekY + 28}, ${CX + jw / 2} ${jawY - 22}, ${CX + jw / 2} ${jawY} ` +
    `C ${CX + jw / 2} ${jawY + (chinY - jawY) * 0.7}, ${CX + (face.faceShape === 'square' ? 24 : 12)} ${chinY}, ${CX} ${chinY} ` +
    `C ${CX - (face.faceShape === 'square' ? 24 : 12)} ${chinY}, ${CX - jw / 2} ${jawY + (chinY - jawY) * 0.7}, ${CX - jw / 2} ${jawY} ` +
    `C ${CX - jw / 2} ${jawY - 22}, ${L} ${cheekY + 28}, ${L} ${cheekY} ` +
    `C ${L} ${TOP + 28}, ${CX - w * 0.3} ${TOP}, ${CX} ${TOP} Z`;

  // ---------- hair ----------
  const hl = L - 7;
  const hr = R + 7;
  const cap = (sideY: number, fringeY: number, part: number, dome: number) =>
    `M ${hl} ${sideY} C ${hl} ${TOP - dome}, ${hr} ${TOP - dome}, ${hr} ${sideY} ` +
    `L ${R - 1} ${sideY} Q ${R - 4} ${fringeY - 4}, ${CX + part} ${fringeY} ` +
    `Q ${L + 4} ${fringeY - 4}, ${L + 1} ${sideY} Z`;
  const wave = (x: number, y1: number, y2: number, dir: number) => {
    let d = '';
    const steps = 5;
    const seg = (y2 - y1) / steps;
    for (let i = 0; i < steps; i++) d += ` Q ${x + dir * (i % 2 ? -7 : 7)} ${y1 + seg * (i + 0.5)}, ${x} ${y1 + seg * (i + 1)}`;
    return d;
  };

  let hairBack: JSX.Element | null = null;
  let hairFront: JSX.Element | null = null;
  const fill = { fill: hairC };
  switch (face.hairStyle) {
    case 'buzz':
      hairFront = <path d={cap(eyeY - 18, TOP + 20, 0, 26)} {...fill} opacity={0.85} />;
      break;
    case 'short':
      hairFront = <path d={cap(eyeY - 8, TOP + 30, -18, 44)} {...fill} />;
      break;
    case 'bob':
      hairBack = <path d={`M ${hl - 4} ${cheekY} C ${hl - 6} ${TOP - 30}, ${hr + 6} ${TOP - 30}, ${hr + 4} ${cheekY} L ${hr + 2} ${jawY + 6} L ${hl - 2} ${jawY + 6} Z`} {...fill} />;
      hairFront = <path d={cap(jawY - 6, TOP + 34, 14, 44)} {...fill} />;
      break;
    case 'long':
      hairBack = <path d={`M ${hl - 2} ${cheekY} C ${hl - 6} ${TOP - 30}, ${hr + 6} ${TOP - 30}, ${hr + 2} ${cheekY} L ${hr + 10} 290 L ${hl - 10} 290 Z`} {...fill} />;
      hairFront = <path d={cap(jawY + 18, TOP + 28, 0, 44)} {...fill} />;
      break;
    case 'wavy':
      hairBack = (
        <path
          d={`M ${hl - 2} ${cheekY} C ${hl - 8} ${TOP - 30}, ${hr + 8} ${TOP - 30}, ${hr + 2} ${cheekY}${wave(hr + 6, cheekY, 288, 1)} L ${hl - 6} 288${wave(hl - 6, 288, cheekY, -1)} Z`}
          {...fill}
        />
      );
      hairFront = <path d={cap(jawY + 12, TOP + 30, -12, 46)} {...fill} />;
      break;
    case 'curly': {
      const curls: JSX.Element[] = [];
      for (let i = 0; i <= 12; i++) {
        const a = Math.PI + (Math.PI * i) / 12;
        curls.push(<circle key={`b${i}`} cx={CX + Math.cos(a) * (w / 2 + 10)} cy={cheekY - 18 + Math.sin(a) * 88} r={19} {...fill} />);
      }
      hairBack = (
        <g>
          {curls}
          <rect x={hl - 14} y={cheekY - 20} width={hr - hl + 28} height={jawY - cheekY + 10} rx={26} {...fill} />
        </g>
      );
      const front: JSX.Element[] = [];
      for (let i = 0; i < 7; i++) {
        const x = L + 8 + ((w - 16) * i) / 6;
        front.push(<circle key={`f${i}`} cx={x} cy={TOP + 10 + Math.abs(i - 3) * 6} r={13} {...fill} />);
      }
      hairFront = <g>{front}</g>;
      break;
    }
    case 'bun':
      hairFront = (
        <g>
          <circle cx={CX} cy={TOP - 22} r={24} {...fill} />
          <path d={cap(eyeY - 12, TOP + 26, 0, 30)} {...fill} />
        </g>
      );
      break;
    case 'ponytail':
      hairBack = <path d={`M ${hr - 14} ${TOP + 30} C ${hr + 26} ${TOP + 40}, ${hr + 22} ${jawY + 40}, ${hr + 4} 280 C ${hr - 6} ${jawY + 30}, ${hr - 6} ${TOP + 60}, ${hr - 14} ${TOP + 30} Z`} {...fill} />;
      hairFront = <path d={cap(eyeY - 12, TOP + 26, -10, 30)} {...fill} />;
      break;
    default: // bald
      hairFront = <ellipse cx={CX - 18} cy={TOP + 16} rx={16} ry={6} fill="#ffffff" opacity={0.18} />;
  }

  // ---------- eyes ----------
  const youngScale = face.age === 'young' ? 1.06 : 1;
  const eye = (cx: number, side: number) => {
    const y = eyeY;
    const k = youngScale;
    let upper: string;
    let lower: string;
    switch (face.eyeShape) {
      case 'round':
        upper = `M ${cx - 12 * k} ${y} C ${cx - 10 * k} ${y - 12 * k}, ${cx + 10 * k} ${y - 12 * k}, ${cx + 12 * k} ${y}`;
        lower = ` C ${cx + 10 * k} ${y + 10 * k}, ${cx - 10 * k} ${y + 10 * k}, ${cx - 12 * k} ${y}`;
        break;
      case 'hooded':
        upper = `M ${cx - 13 * k} ${y + 1} Q ${cx} ${y - 6 * k}, ${cx + 13 * k} ${y}`;
        lower = ` Q ${cx} ${y + 8 * k}, ${cx - 13 * k} ${y + 1}`;
        break;
      case 'monolid':
        upper = `M ${cx - 13 * k} ${y + side} Q ${cx} ${y - 6 * k}, ${cx + 13 * k} ${y - side}`;
        lower = ` Q ${cx} ${y + 5 * k}, ${cx - 13 * k} ${y + side}`;
        break;
      default: // almond
        upper = `M ${cx - 13 * k} ${y + 1} Q ${cx} ${y - 10 * k}, ${cx + 13 * k} ${y - 1}`;
        lower = ` Q ${cx} ${y + 8 * k}, ${cx - 13 * k} ${y + 1}`;
    }
    const clip = `eye${uid}${side}`;
    const outer = cx + side * 13 * k;
    return (
      <g key={side}>
        <clipPath id={clip}>
          <path d={upper + lower} />
        </clipPath>
        <path d={upper + lower} fill="#FBF7F3" />
        <g clipPath={`url(#${clip})`}>
          <circle cx={cx} cy={y + 0.5} r={6.4 * k} fill={IRIS[face.eyeColor]} />
          <circle cx={cx} cy={y + 0.5} r={6.4 * k} fill="none" stroke="#000" strokeOpacity={0.25} strokeWidth={1.2} />
          <circle cx={cx} cy={y + 0.5} r={2.9 * k} fill="#120c0a" />
          <circle cx={cx + 2.2} cy={y - 1.8} r={1.5} fill="#fff" />
        </g>
        <path d={upper} fill="none" stroke="#2A1C16" strokeWidth={masc ? 1.8 : 2.6} strokeLinecap="round" />
        {!masc && <path d={`M ${outer} ${y - 1} l ${side * 4} -3`} stroke="#2A1C16" strokeWidth={1.6} strokeLinecap="round" />}
        {face.eyeShape === 'hooded' && (
          <path d={`M ${cx - 13 * k} ${y - 4} Q ${cx} ${y - 12 * k}, ${cx + 14 * k} ${y - 3}`} fill="none" stroke={line} strokeOpacity={0.55} strokeWidth={1.3} />
        )}
        {face.eyeShape === 'round' && (
          <path d={`M ${cx - 10} ${y - 14} Q ${cx} ${y - 18}, ${cx + 10} ${y - 14}`} fill="none" stroke={line} strokeOpacity={0.35} strokeWidth={1.1} />
        )}
      </g>
    );
  };

  // ---------- brows ----------
  const browW = { thin: 2.2, natural: 3.4, bold: 5 }[face.brows] ?? 3.4;
  const brow = (cx: number, side: number) => {
    const by = eyeY - 17;
    const inner = cx - side * 13;
    const outer = cx + side * 15;
    const arch = masc ? 3 : 6;
    return (
      <path
        key={`b${side}`}
        d={`M ${inner} ${by + 2} Q ${cx + side * 3} ${by - arch}, ${outer} ${by + 3}`}
        fill="none"
        stroke={browC}
        strokeWidth={browW + (masc ? 1 : 0)}
        strokeLinecap="round"
      />
    );
  };

  // ---------- nose ----------
  const nw = { button: 7, straight: 8, wide: 12, roman: 9 }[face.nose] ?? 8;
  const bridge =
    face.nose === 'roman'
      ? `M ${CX + 4} ${eyeY + 6} Q ${CX + 9} ${eyeY + 16}, ${CX + 7} ${noseY - 10} Q ${CX + 9} ${noseY - 4}, ${CX + nw} ${noseY - 1}`
      : face.nose === 'button'
        ? `M ${CX + 5} ${noseY - 12} Q ${CX + 9} ${noseY - 6}, ${CX + nw} ${noseY - 1}`
        : `M ${CX + 4} ${eyeY + 8} Q ${CX + 7} ${noseY - 12}, ${CX + nw} ${noseY - 1}`;

  // ---------- mouth ----------
  const mw = { thin: 30, medium: 32, full: 34 }[face.lips] ?? 32;
  const [uh, lh] = ({ thin: [3, 4], medium: [5, 7], full: [7, 10] } as Record<string, number[]>)[face.lips] ?? [5, 7];
  const ml = CX - mw / 2;
  const mr = CX + mw / 2;
  const dl = face.expression === 'smile' ? -4 : 0;
  const dr = face.expression === 'calm' ? 0 : -4;
  const sag = face.expression === 'smile' ? 4 : face.expression === 'smirk' ? 2 : 1;
  const my = mouthY;
  const upperLip =
    `M ${ml} ${my + dl} C ${CX - mw / 4} ${my - uh}, ${CX - 4} ${my - uh - 1}, ${CX} ${my - uh + 2} ` +
    `C ${CX + 4} ${my - uh - 1}, ${CX + mw / 4} ${my - uh}, ${mr} ${my + dr} Q ${CX} ${my + sag}, ${ml} ${my + dl} Z`;
  const lowerLip = `M ${ml} ${my + dl} Q ${CX} ${my + sag}, ${mr} ${my + dr} Q ${CX} ${my + lh + sag + 2}, ${ml} ${my + dl} Z`;
  const mouthLine = `M ${ml} ${my + dl} Q ${CX} ${my + sag}, ${mr} ${my + dr}`;

  // ---------- facial hair ----------
  const beardShape =
    `M ${L + 2} ${eyeY + 14} L ${CX - jw / 2 - 3} ${jawY} C ${CX - jw / 2 - 2} ${chinY + 4}, ${CX - 24} ${chinY + 16}, ${CX} ${chinY + 16} ` +
    `C ${CX + 24} ${chinY + 16}, ${CX + jw / 2 + 2} ${chinY + 4}, ${CX + jw / 2 + 3} ${jawY} L ${R - 2} ${eyeY + 14} ` +
    `Q ${CX + w * 0.28} ${my - 4}, ${CX} ${my - uh - 9} Q ${CX - w * 0.28} ${my - 4}, ${L + 2} ${eyeY + 14} Z`;
  const stache = `M ${ml - 4} ${my + dl + 1} Q ${CX - 10} ${my - uh - 11}, ${CX} ${my - uh - 5} Q ${CX + 10} ${my - uh - 11}, ${mr + 4} ${my + dr + 1} Q ${CX} ${my - uh - 2}, ${ml - 4} ${my + dl + 1} Z`;

  // ---------- glasses ----------
  const lx = CX - 26;
  const rx = CX + 26;
  let glasses: JSX.Element | null = null;
  if (face.glasses !== 'none') {
    const frame = { fill: '#ffffff', fillOpacity: 0.1, stroke: '#1d1a1c', strokeWidth: 2.6 };
    glasses = (
      <g>
        {face.glasses === 'round' ? (
          <>
            <circle cx={lx} cy={eyeY} r={16} {...frame} />
            <circle cx={rx} cy={eyeY} r={16} {...frame} />
          </>
        ) : (
          <>
            <rect x={lx - 18} y={eyeY - 12} width={36} height={25} rx={5} {...frame} />
            <rect x={rx - 18} y={eyeY - 12} width={36} height={25} rx={5} {...frame} />
          </>
        )}
        <path d={`M ${lx + 16} ${eyeY - 2} Q ${CX} ${eyeY - 8}, ${rx - 16} ${eyeY - 2}`} fill="none" stroke="#1d1a1c" strokeWidth={2.4} />
        <path d={`M ${lx - 17} ${eyeY - 3} L ${L} ${eyeY - 5} M ${rx + 17} ${eyeY - 3} L ${R} ${eyeY - 5}`} stroke="#1d1a1c" strokeWidth={2.4} />
      </g>
    );
  }

  return (
    <svg viewBox="0 0 240 300" className={className} role="img" aria-label={title ?? 'Generated face'}>
      <rect width="240" height="300" fill={backdrop} />
      <circle cx={CX} cy={150} r={112} fill="#ffffff" opacity={0.25} />
      {hairBack}
      {/* neck + shoulders */}
      <path d={`M ${CX - 22} ${jawY - 24} L ${CX - 25} 262 L ${CX + 25} 262 L ${CX + 22} ${jawY - 24} Z`} fill={shade} />
      <path d={`M 14 300 Q 18 262 76 254 Q ${CX} 274 164 254 Q 222 262 226 300 Z`} fill={shirt} />
      <path d={`M 98 254 Q ${CX} 276 142 254`} fill="none" stroke={darken(shirt, 0.25)} strokeWidth={3} />
      {/* ears */}
      <ellipse cx={L + 1} cy={eyeY + 14} rx={8} ry={14} fill={skin} />
      <ellipse cx={R - 1} cy={eyeY + 14} rx={8} ry={14} fill={skin} />
      <ellipse cx={L + 1} cy={eyeY + 14} rx={4} ry={8} fill={shade} opacity={0.6} />
      <ellipse cx={R - 1} cy={eyeY + 14} rx={4} ry={8} fill={shade} opacity={0.6} />
      {/* head */}
      <path d={head} fill={skin} />
      {(face.expression === 'smile' || !masc) && (
        <>
          <ellipse cx={CX - 34} cy={eyeY + 26} rx={13} ry={8} fill={lip} opacity={0.22} />
          <ellipse cx={CX + 34} cy={eyeY + 26} rx={13} ry={8} fill={lip} opacity={0.22} />
        </>
      )}
      {face.age === 'mature' && (
        <g fill="none" stroke={line} strokeOpacity={0.4} strokeWidth={1.3} strokeLinecap="round">
          <path d={`M ${CX - 14} ${noseY + 4} Q ${CX - 24} ${my - 4}, ${CX - 22} ${my + 8}`} />
          <path d={`M ${CX + 14} ${noseY + 4} Q ${CX + 24} ${my - 4}, ${CX + 22} ${my + 8}`} />
          <path d={`M ${lx - 8} ${eyeY + 10} Q ${lx} ${eyeY + 14}, ${lx + 8} ${eyeY + 10}`} />
          <path d={`M ${rx - 8} ${eyeY + 10} Q ${rx} ${eyeY + 14}, ${rx + 8} ${eyeY + 10}`} />
        </g>
      )}
      {face.facialHair === 'stubble' && <path d={beardShape} fill={hairC} opacity={0.24} />}
      {face.facialHair === 'beard' && <path d={beardShape} fill={hairC} />}
      {eye(lx, -1)}
      {eye(rx, 1)}
      {brow(lx, -1)}
      {brow(rx, 1)}
      <path d={bridge} fill="none" stroke={line} strokeOpacity={0.7} strokeWidth={1.8} strokeLinecap="round" />
      <path d={`M ${CX - nw} ${noseY} Q ${CX} ${noseY + 6}, ${CX + nw} ${noseY}`} fill="none" stroke={line} strokeOpacity={0.75} strokeWidth={2} strokeLinecap="round" />
      <path d={lowerLip} fill={lip} />
      <path d={upperLip} fill={darken(lip, 0.12)} />
      <path d={mouthLine} fill="none" stroke={darken(lip, 0.45)} strokeWidth={1.6} strokeLinecap="round" />
      {(face.facialHair === 'mustache' || face.facialHair === 'beard') && <path d={stache} fill={hairC} />}
      {hairFront}
      {glasses}
    </svg>
  );
}
