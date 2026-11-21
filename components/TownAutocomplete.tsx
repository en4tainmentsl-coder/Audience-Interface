import React, { useEffect, useId, useRef, useState } from 'react';
import { supabase } from '../services/supabase';

// Town picker for the event location on a quote request.
//
// WHY THIS REPLACED DISTRICT CENTROIDS
// quote_requests carries a CHECK:
//     CHECK (venue_id IS NOT NULL
//            OR (event_latitude IS NOT NULL AND event_longitude IS NOT NULL))
// That was previously satisfied with one of 26 district centroids, which is
// enough to answer "is a Kandy act realistic for a Colombo wedding" but not to
// price travel. Travel is charged per kilometre on the Haversine distance from
// the talent's base (D-005), so a district centroid can be tens of kilometres
// out: a booking about 1 km from the talent priced at 16.62 km and Rs 4,986 on
// 2026-11-21. Towns are the same two columns and the same code path - only the
// input component changed, exactly as constants/districts.ts anticipated.
//
// PRIVACY
// districts.ts noted a deliberate benefit: a private wedding at a family home
// stored a district centroid rather than the household's coordinates. A town
// centroid is finer but is still a town, not an address - and event_address
// already stores the typed street address for every non-venue booking, so the
// row carries finer location than either centroid regardless.
//
// WHY A PICK, NOT TYPED TEXT
// 1,523 town names are duplicated across districts (4,506 of 17,564 rows share
// a name), so a typed name cannot be resolved to one place. Labels are unique -
// "Athurugiriya, Colombo" - and what is stored is the chosen row's coordinates,
// so there is no name matching to get wrong.
//
// Data: GeoNames, CC BY 4.0. The attribution line below is a licence requirement.

export type TownPick = {
  id: number;
  label: string;
  latitude: number;
  longitude: number;
};

type TownRow = {
  id: number;
  name: string;
  label: string;
  rank: number;
  latitude: number;
  longitude: number;
};

interface Props {
  /** Text shown in the field. */
  value: string;
  /** The currently chosen town, or null if none has been picked. */
  townId: number | null;
  /** pick is null while the client is typing; set once they choose a town. */
  onChange: (pick: TownPick | null, text: string) => void;
  invalid?: boolean;
}

const MIN_CHARS = 2;
const MAX_SHOWN = 8;
const DEBOUNCE_MS = 200;

// % and _ are wildcards in ILIKE; escape them so they match literally.
const escapeLike = (s: string) => s.replace(/[\\%_]/g, (m) => '\\' + m);

export const TownAutocomplete: React.FC<Props> = ({ value, townId, onChange, invalid }) => {
  const [open, setOpen] = useState(false);
  const [results, setResults] = useState<TownRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [active, setActive] = useState(-1);
  const requestId = useRef(0);
  const listId = useId();

  useEffect(() => {
    if (!open) return;
    const q = value.trim();
    if (q.length < MIN_CHARS) {
      setResults([]);
      setLoading(false);
      return;
    }

    const id = ++requestId.current;
    setLoading(true);
    const timer = setTimeout(async () => {
      const { data, error } = await supabase
        .from('towns')
        .select('id, name, label, rank, latitude, longitude')
        .ilike('name', `%${escapeLike(q)}%`)
        .order('rank', { ascending: false })
        .limit(40);

      // Ignore responses that arrive after a newer keystroke.
      if (id !== requestId.current) return;

      setLoading(false);
      if (error) {
        console.error('Town search failed:', error);
        setFailed(true);
        setResults([]);
        return;
      }
      setFailed(false);

      // Best matches first: well-known towns, then names that START with what
      // was typed, then shorter names.
      const lower = q.toLowerCase();
      const sorted = ((data ?? []) as TownRow[]).sort(
        (a, b) =>
          b.rank - a.rank ||
          Number(b.name.toLowerCase().startsWith(lower)) -
            Number(a.name.toLowerCase().startsWith(lower)) ||
          a.name.length - b.name.length,
      );
      setResults(sorted.slice(0, MAX_SHOWN));
      setActive(-1);
    }, DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [value, open]);

  const pick = (t: TownRow) => {
    onChange(
      { id: t.id, label: t.label, latitude: Number(t.latitude), longitude: Number(t.longitude) },
      t.label,
    );
    setOpen(false);
    setResults([]);
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!open || results.length === 0) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((i) => (i + 1) % results.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((i) => (i <= 0 ? results.length - 1 : i - 1));
    } else if (e.key === 'Enter') {
      // Without this, Enter would submit the whole quote request form.
      e.preventDefault();
      if (active >= 0) pick(results[active]);
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  };

  const showList = open && value.trim().length >= MIN_CHARS;

  return (
    <div className="relative">
      <input
        type="text"
        role="combobox"
        aria-expanded={showList}
        aria-controls={listId}
        aria-autocomplete="list"
        aria-activedescendant={active >= 0 ? `${listId}-${active}` : undefined}
        autoComplete="off"
        placeholder="Start typing the town"
        value={value}
        onChange={(e) => {
          // Any edit discards the previous pick: the text no longer names a chosen town.
          onChange(null, e.target.value);
          setOpen(true);
        }}
        onFocus={() => {
          if (!townId && value.trim().length >= MIN_CHARS) setOpen(true);
        }}
        onBlur={() => setOpen(false)}
        onKeyDown={onKeyDown}
        className={`w-full bg-brand-dark/50 border rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all ${
          invalid ? 'border-red-500' : 'border-white/10'
        }`}
      />

      {showList && (
        <ul
          id={listId}
          role="listbox"
          className="absolute z-20 mt-1 w-full max-h-64 overflow-auto rounded-xl border border-white/10 bg-brand-surface shadow-lg"
        >
          {loading && results.length === 0 && (
            <li className="p-3 text-sm text-gray-400">Searching…</li>
          )}
          {!loading && failed && (
            <li className="p-3 text-sm text-red-400">Couldn't load towns. Please try again.</li>
          )}
          {!loading && !failed && results.length === 0 && (
            <li className="p-3 text-sm text-gray-400">
              No towns match. Check the spelling, or try a nearby town.
            </li>
          )}
          {results.map((t, i) => (
            <li
              key={t.id}
              id={`${listId}-${i}`}
              role="option"
              aria-selected={i === active}
              // mousedown, not click: it fires before the input's blur closes the list.
              onMouseDown={(e) => {
                e.preventDefault();
                pick(t);
              }}
              onMouseEnter={() => setActive(i)}
              className={`cursor-pointer px-3 py-2 text-sm ${
                i === active ? 'bg-brand-purple/20 text-white' : 'text-gray-200 hover:bg-white/5'
              }`}
            >
              {t.label}
            </li>
          ))}
        </ul>
      )}

      <p className="mt-1 text-xs text-gray-500">
        {townId
          ? 'Travel is measured from the centre of this town.'
          : 'Start typing, then choose the town from the list.'}
      </p>
      <p className="text-[10px] text-gray-600">
        Town list:{' '}
        <a
          href="https://www.geonames.org"
          target="_blank"
          rel="noopener noreferrer"
          className="underline"
        >
          GeoNames
        </a>
        , CC BY 4.0
      </p>
    </div>
  );
};
