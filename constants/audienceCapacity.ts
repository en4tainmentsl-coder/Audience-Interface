// Audience capacity bands. The three-way split at 100 and 300 is fixed by
// ACPOSL Tariff 6.3, which prices public performance by audience size:
// small (<100), medium (100–300), large (>300). The finer bands above 300
// are ours — they tell the talent what they are walking into and feed our
// own pricing. For licensing, anything above 300 collapses back to "large".
//
// Boundaries do not overlap: 300 belongs to 100_to_300, 750 to 301_to_750.

export const AUDIENCE_CAPACITY_BANDS = [
  { value: 'under_100',   label: 'Under 100' },
  { value: '100_to_300',  label: '100 - 300' },
  { value: '301_to_750',  label: '301 - 750' },
  { value: '751_to_1500', label: '751 - 1,500' },
  { value: 'over_1500',   label: 'Over 1,500' },
] as const;

export type AudienceCapacityBand = typeof AUDIENCE_CAPACITY_BANDS[number]['value'];