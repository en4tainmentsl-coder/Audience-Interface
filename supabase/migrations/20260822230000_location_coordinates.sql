-- Applied via Supabase SQL Editor 2026-08-22.
--
-- Adds coordinate pins so travel distance can be computed and so v2 floated
-- quotes can be filtered to talent within a practical perimeter of the venue.
--
-- Plain numeric rather than PostGIS: zero rows, low volume, and no need for
-- spatial indexing yet. Forward-compatible -- a PostGIS geography generated
-- column can be derived from these same lat/lng columns later without
-- migrating data.
--
-- numeric(9,6) is ~10cm precision, ample, and prevents storing float noise.
--
-- quote_requests_has_location: a request must have EITHER a venue (coords
-- inherited from the venue profile) OR an explicit pin for a private address.
-- Covers both booking paths without forcing coords on venue bookings.
--
-- travel_radius_km is the cleaner implementation of what the five
-- optional_location_* text fields were reaching for -- a perimeter from base
-- rather than a list of place names to string-match.
--
-- distance_km is Haversine, verified against known pairs:
--   Colombo-Kandy 94.34km, Colombo-Galle 104.96km, same point 0.00km.
-- NOTE: straight-line, not road distance. Colombo-Kandy is ~115km by road.
-- Use for radius filtering and as a talent reference only -- travel fees are
-- manually entered. Label it as approximate in the UI.

-- Talent: base location for travel-distance origin, and coverage radius
ALTER TABLE public.profiles_talent
  ADD COLUMN base_latitude   numeric(9,6),
  ADD COLUMN base_longitude  numeric(9,6),
  ADD COLUMN travel_radius_km integer;

ALTER TABLE public.profiles_talent
  ADD CONSTRAINT profiles_talent_base_coords_valid
    CHECK ((base_latitude IS NULL AND base_longitude IS NULL)
        OR (base_latitude BETWEEN -90 AND 90 AND base_longitude BETWEEN -180 AND 180)),
  ADD CONSTRAINT profiles_talent_travel_radius_valid
    CHECK (travel_radius_km IS NULL OR travel_radius_km BETWEEN 1 AND 1000);

-- Venues: pin alongside the existing structured address
ALTER TABLE public.profiles_venues
  ADD COLUMN latitude  numeric(9,6),
  ADD COLUMN longitude numeric(9,6);

ALTER TABLE public.profiles_venues
  ADD CONSTRAINT profiles_venues_coords_valid
    CHECK ((latitude IS NULL AND longitude IS NULL)
        OR (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180));

-- Quote requests: event pin and free-text address
ALTER TABLE public.quote_requests
  ADD COLUMN event_latitude  numeric(9,6),
  ADD COLUMN event_longitude numeric(9,6),
  ADD COLUMN event_address   text;

ALTER TABLE public.quote_requests
  ADD CONSTRAINT quote_requests_coords_valid
    CHECK ((event_latitude IS NULL AND event_longitude IS NULL)
        OR (event_latitude BETWEEN -90 AND 90 AND event_longitude BETWEEN -180 AND 180));

-- Either a venue (coords inherited from the venue profile) or an explicit pin.
ALTER TABLE public.quote_requests
  ADD CONSTRAINT quote_requests_has_location
    CHECK (venue_id IS NOT NULL
        OR (event_latitude IS NOT NULL AND event_longitude IS NOT NULL));

-- Haversine great-circle distance in km
CREATE OR REPLACE FUNCTION public.distance_km(
  lat1 numeric, lon1 numeric, lat2 numeric, lon2 numeric
) RETURNS numeric
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path TO 'public'
AS $$
  SELECT round((6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * power(sin(radians(lon2 - lon1) / 2), 2)
  )))::numeric, 2);
$$;
