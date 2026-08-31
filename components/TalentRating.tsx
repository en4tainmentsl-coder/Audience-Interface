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
 * Display rule (decision 2026-08-31): the public sees the aggregate only,
 * never individual reviews, and the count is ALWAYS shown beside the average.
 * An unrated talent shows "— (0)", never "0.0" and never "5.0" — a number
 * would read as a judgement nobody made.
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
   *  'full'    = five stars + number (artist detail hero). */
  variant?: 'compact' | 'full';
  size?: number;
  className?: string;
}

export const TalentRating: React.FC<TalentRatingProps> = ({
  stats,
  variant = 'compact',
  size = 16,
  className = '',
}) => {
  const { average, count } = normaliseTalentStats(stats);
  const unrated = average === null;
  const filled = unrated ? 0 : Math.round(average);

  return (
    <span
      className={`inline-flex items-center gap-1.5 ${className}`}
      id="talent-rating"
      title={unrated ? 'No ratings yet' : `${average.toFixed(1)} from ${count} rating${count === 1 ? '' : 's'}`}
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
        <Star
          size={size}
          className={unrated ? 'fill-transparent text-gray-600' : 'fill-brand-lime text-brand-lime'}
        />
      )}

      <span className={unrated ? 'text-gray-500' : ''}>
        {unrated ? '—' : average.toFixed(1)}
      </span>
      <span className="text-gray-500">({count})</span>
    </span>
  );
};