import type { Database } from '../database.types';

export type EventType = Database['public']['Enums']['events_type'];

// Mirrors the events_type enum. Adding a value here without adding it to the
// enum, or vice versa, breaks quote requests — rate_category_for_event_type
// raises on an unmapped type rather than silently returning NULL.
export const EVENT_TYPES: { value: EventType; label: string }[] = [
  { value: 'wedding', label: 'Wedding' },
  { value: 'corporate', label: 'Corporate' },
  { value: 'birthday', label: 'Birthday' },
  { value: 'concert', label: 'Concert' },
  { value: 'private', label: 'Private Event' },
  { value: 'club_pub', label: 'Club or Pub' },
  { value: 'dinner_service', label: 'Dinner Service' },
  { value: 'lunch_service', label: 'Lunch Service' },
  { value: 'spot_performance', label: 'Spot Performance' },
];

export const eventTypeLabel = (v: string | null | undefined): string =>
  EVENT_TYPES.find(e => e.value === v)?.label ?? '';