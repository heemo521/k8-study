import { useState } from 'react';
import FaceSvg from './FaceSvg';
import type { Face } from '../lib/traits';

interface Props {
  seeds: Face[];
  onPick: (winner: Face, loser: Face) => void;
  onDone: (champion: Face, runnersUp: Face[]) => void;
}

const ROUND_NAMES: Record<number, string> = { 8: 'Quarterfinal', 4: 'Semifinal', 2: 'Final' };

/** Single-elimination bracket: pick one of two until one face is left. */
export default function FaceOff({ seeds, onPick, onDone }: Props) {
  const [round, setRound] = useState<Face[]>(seeds);
  const [winners, setWinners] = useState<Face[]>([]);
  const [eliminated, setEliminated] = useState<Face[]>([]);
  const [match, setMatch] = useState(0);

  const a = round[match * 2];
  const b = round[match * 2 + 1];

  const choose = (winner: Face, loser: Face) => {
    onPick(winner, loser);
    const nextWinners = [...winners, winner];
    // Most recent losers made it furthest, so they lead the runners-up list.
    const nextOut = [loser, ...eliminated];
    if ((match + 1) * 2 >= round.length) {
      if (nextWinners.length === 1) {
        onDone(nextWinners[0], nextOut);
        return;
      }
      setRound(nextWinners);
      setWinners([]);
      setMatch(0);
    } else {
      setWinners(nextWinners);
      setMatch(match + 1);
    }
    setEliminated(nextOut);
  };

  if (!a || !b) return null;
  const matches = round.length / 2;

  return (
    <div className="faceoff">
      <p className="eyebrow">
        {ROUND_NAMES[round.length] ?? 'Round'} · match {match + 1} of {matches}
      </p>
      <h2 className="screen-title">Who's more your type?</h2>
      <div className="faceoff-pair">
        <button className="faceoff-pick" onClick={() => choose(a, b)}>
          <FaceSvg face={a} className="card-face" title="Option A" />
          <span>This one</span>
        </button>
        <span className="faceoff-vs" aria-hidden="true">
          or
        </span>
        <button className="faceoff-pick" onClick={() => choose(b, a)}>
          <FaceSvg face={b} className="card-face" title="Option B" />
          <span>This one</span>
        </button>
      </div>
    </div>
  );
}
