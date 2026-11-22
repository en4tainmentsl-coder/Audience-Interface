/**
 * Single definition of how money renders anywhere in the app.
 *
 * House rule: LKR, thousands separators, always 2 decimals — `LKR 21,597.31`.
 *
 * Two things this exists to absorb:
 *
 * 1. PostgREST serialises `numeric` as a STRING. `total_client_price` arrives
 *    as "21597.31", not 21597.31, so arithmetic or .toFixed() on it directly
 *    misbehaves. Always Number() first — the same trap TalentRating documents
 *    for rating_average.
 *
 * 2. A null amount is not zero. A quote with no VAT yet has `vat_amount: null`,
 *    and rendering that as "LKR 0.00" asserts a figure nobody calculated.
 *    Null renders as an em dash.
 *
 * Currency is a column on bookings and payments rather than a constant, so it
 * is a parameter — but it defaults to LKR, which is all the platform handles
 * today.
 */
export const formatMoney = (
  value: string | number | null | undefined,
  currency: string = 'LKR',
): string => {
  if (value == null || value === '') return '—';

  const n = Number(value);
  if (!Number.isFinite(n)) return '—';

  return `${currency} ${n.toLocaleString('en-LK', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
};
