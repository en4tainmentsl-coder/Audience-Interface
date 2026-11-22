import React from 'react';
import { Star } from 'lucide-react';
import type { RawTalentStats } from '../types';

/**
 * Single definition of how a talent's rating renders anywhere in the app.
 *
 * Two things this exists to absorb:
 *
 * 1. PostgREST serialises `numeric` as a STRING. rating_average arrives as
 *    "4.667", not 4.667, so .toFixed() on it directly throws. Always Number().
 *
 * 2. talent_stats.talent_id is both PK and FK, so PostgREST should embed it
 *    as an object rather than an array — but an unrated talent has NO
 *    talent_stats row at all, and that absence IS the "no ratings yet" state.
 *    So the value can be an object, an array, null, or undefined. Normalised
 *    here once rather than guessed at seven call sites.
 *
 * Display rule (decision 2026-08-31, REVISED 2026-11-22): the public sees the
 * aggregate only, never individual reviews, and the count is always shown
 * beside the average. An unrated talent never shows a number — not "0.0", not
 * "5.0" — because a number reads as a judgement nobody made. That part stands.
 *
 * What changed on 2026-11-22: an unrated talent used to render five grey stars
 * plus "— (0)". Five empty stars do not read as "no data", they read as zero
 * out of five. The January launch is talent-supply only, so NO talent has a
 * rating — every card in the roster would have shown an apparently terrible
 * score on the one page that exists to sell those acts.
 *
 * So an unrated talent now shows the words "No ratings yet" and no stars at
 * all, and public card grids pass hideWhenUnrated to omit the block entirely.
 * Nothing there says nothing, which is accurate. Empty stars say something
 * false. This matches eBay, which shows no feedback percentage for a seller
 * who has none rather than defaulting them to a score.
 *
 * A 5-star default for new talent was considered and rejected 2026-11-22: it
 * is a false representation of grade under the Consumer Affairs Authority Act
 * No. 9 of 2003 ss.30-31, and it can only ever ratchet downward, so a talent's
 * first honest review would make them look worse than an untested peer.
 *
 * Planned for the April phase, once real ratings exist: a Bayesian-shrunk
 * average so one unlucky first review cannot sink a good act. Not possible in
 * January — with no ratings anywhere there is no platform mean to shrink
 * toward, and shrinking from nothing is the same fabrication in better
 * clothes.
 */

export function normaliseTalentStats(
  raw: RawTalentStats
): { average: number | null; count: number } {
  const row = Array.isArray(raw) ? raw[0] : raw;

  const count = Number(row?.rating_count ?? 0);
  if (!Number.isFinite(count) || count <= 0) {
    return { average: null, count: 0 };
  }

  const average = Number(row?.rating_average);
  return {
    average: Number.isFinite(average) ? average : null,
    count,
  };
}

interface TalentRatingProps {
  stats: RawTalentStats;
  /** 'compact' = one star + number (cards, dashboards).
   *  'full'    = five stars + number (artist detail hero).
   *  Applies to RATED talent only; an unrated talent renders the same either
   *  way, because the stars are the part that misleads. */
  variant?: 'compact' | 'full';
  size?: number;
  className?: string;
  /**
   * Render nothing at all when the talent has no ratings.
   *
   * Opt-in, not the default. On a public card grid a gap is cleaner than a
   * label repeated down every card. But a talent looking at their own
   * dashboard, or a venue reading a quote, is better served by being told
   * there are no ratings than by a blank space they have to interpret.
   */
  hideWhenUnrated?: boolean;
}

export const TalentRating: React.FC<TalentRatingProps> = ({
  stats,
  variant = 'compact',
  size = 16,
  className = '',
  hideWhenUnrated = false,
}) => {
  const { average, count } = normaliseTalentStats(stats);
  const unrated = average === null;

  if (unrated && hideWhenUnrated) return null;

  if (unrated) {
    return (
      <span className={`inline-flex items-center text-gray-500 ${className}`} id="talent-rating">
        No ratings yet
      </span>
    );
  }

  const filled = Math.round(average);

  return (
    <span
      className={`inline-flex items-center gap-1.5 ${className}`}
      id="talent-rating"
      title={`${average.toFixed(1)} from ${count} rating${count === 1 ? '' : 's'}`}
    >
      {variant === 'full' ? (
        <span className="flex gap-1">
          {[1, 2, 3, 4, 5].map((star) => (
            <Star
              key={star}
              size={size}
              className={star <= filled ? 'fill-brand-lime text-brand-lime' : 'fill-transparent text-gray-600'}
            />
          ))}
        </span>
      ) : (
        <Star size={size} className="fill-brand-lime text-brand-lime" />
      )}

      <span>{average.toFixed(1)}</span>
      <span className="text-gray-500">({count})</span>
    </span>
  );
};