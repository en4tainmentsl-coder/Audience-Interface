// Sri Lanka administrative districts with representative coordinates.
//
// WHY THIS EXISTS
// `quote_requests` carries a CHECK constraint:
//     CHECK (venue_id IS NOT NULL
//            OR (event_latitude IS NOT NULL AND event_longitude IS NOT NULL))
// A free-text location string does not satisfy it. These centroids give every
// quote request a usable coordinate pair without an external geocoding provider,
// an API key, or a public proxy endpoint.
//
// PRECISION
// District-level only. Good enough to answer "is a Kandy act realistic for a
// Colombo wedding" via the Haversine distance_km function. Not an address.
// When place-search geocoding lands, it replaces these as a precision upgrade —
// same two columns, same code path, only the input component changes.
//
// PRIVACY NOTE
// A deliberate benefit: a private wedding at a family home stores a district
// centroid, not the household's actual coordinates. Keep it that way unless
// there is a concrete reason to store finer location for private events.

export interface District {
  code: string;
  name: string;
  province: string;
  latitude: number;
  longitude: number;
}

export const DISTRICTS: District[] = [
  // Western
  { code: 'colombo',      name: 'Colombo',      province: 'Western',        latitude: 6.9271, longitude: 79.8612 },
  { code: 'gampaha',      name: 'Gampaha',      province: 'Western',        latitude: 7.0840, longitude: 79.9990 },
  { code: 'kalutara',     name: 'Kalutara',     province: 'Western',        latitude: 6.5854, longitude: 79.9607 },
  // Central
  { code: 'kandy',        name: 'Kandy',        province: 'Central',        latitude: 7.2906, longitude: 80.6337 },
  { code: 'matale',       name: 'Matale',       province: 'Central',        latitude: 7.4675, longitude: 80.6234 },
  { code: 'nuwara_eliya', name: 'Nuwara Eliya', province: 'Central',        latitude: 6.9497, longitude: 80.7891 },
  // Southern
  { code: 'galle',        name: 'Galle',        province: 'Southern',       latitude: 6.0535, longitude: 80.2210 },
  { code: 'matara',       name: 'Matara',       province: 'Southern',       latitude: 5.9549, longitude: 80.5550 },
  { code: 'hambantota',   name: 'Hambantota',   province: 'Southern',       latitude: 6.1240, longitude: 81.1185 },
  // Northern
  { code: 'jaffna',       name: 'Jaffna',       province: 'Northern',       latitude: 9.6615, longitude: 80.0255 },
  { code: 'kilinochchi',  name: 'Kilinochchi',  province: 'Northern',       latitude: 9.3803, longitude: 80.3770 },
  { code: 'mannar',       name: 'Mannar',       province: 'Northern',       latitude: 8.9810, longitude: 79.9044 },
  { code: 'vavuniya',     name: 'Vavuniya',     province: 'Northern',       latitude: 8.7514, longitude: 80.4971 },
  { code: 'mullaitivu',   name: 'Mullaitivu',   province: 'Northern',       latitude: 9.2671, longitude: 80.8142 },
  // Eastern
  { code: 'batticaloa',   name: 'Batticaloa',   province: 'Eastern',        latitude: 7.7102, longitude: 81.6924 },
  { code: 'ampara',       name: 'Ampara',       province: 'Eastern',        latitude: 7.2917, longitude: 81.6725 },
  { code: 'trincomalee',  name: 'Trincomalee',  province: 'Eastern',        latitude: 8.5874, longitude: 81.2152 },
  // North Western
  { code: 'kurunegala',   name: 'Kurunegala',   province: 'North Western',  latitude: 7.4863, longitude: 80.3647 },
  { code: 'puttalam',     name: 'Puttalam',     province: 'North Western',  latitude: 8.0362, longitude: 79.8283 },
  // North Central
  { code: 'anuradhapura', name: 'Anuradhapura', province: 'North Central',  latitude: 8.3114, longitude: 80.4037 },
  { code: 'polonnaruwa',  name: 'Polonnaruwa',  province: 'North Central',  latitude: 7.9403, longitude: 81.0188 },
  // Uva
  { code: 'badulla',      name: 'Badulla',      province: 'Uva',            latitude: 6.9895, longitude: 81.0557 },
  { code: 'monaragala',   name: 'Monaragala',   province: 'Uva',            latitude: 6.8728, longitude: 81.3510 },
  // Sabaragamuwa
  { code: 'ratnapura',    name: 'Ratnapura',    province: 'Sabaragamuwa',   latitude: 6.6828, longitude: 80.3992 },
  { code: 'kegalle',      name: 'Kegalle',      province: 'Sabaragamuwa',   latitude: 7.2513, longitude: 80.3464 },
];

export const findDistrict = (code: string): District | undefined =>
  DISTRICTS.find((d) => d.code === code);
