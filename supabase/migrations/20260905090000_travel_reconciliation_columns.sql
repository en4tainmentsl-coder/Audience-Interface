-- Travel reconciliation detail. Praveen 2026-09-05: record these so a
-- disputed travel charge is answerable, but do NOT surface them on the
-- client-facing quote.
--
-- travel_distance_km is the ONE-WAY Haversine distance. The charge
-- doubles it for the return leg. NULL when coordinates were unavailable
-- and the percentage fallback was used.

ALTER TABLE public.quotes
  ADD COLUMN travel_distance_km           numeric(10,2),
  ADD COLUMN travel_coordinates_estimated boolean NOT NULL DEFAULT false;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_travel_distance_sane
  CHECK (travel_distance_km IS NULL OR travel_distance_km >= 0);

-- A distance and the estimated flag are mutually exclusive: either the
-- coordinates were known and a real distance was measured, or they were
-- not and the fallback percentage was applied.
ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_travel_estimate_consistent
  CHECK (
    (travel_coordinates_estimated = true  AND travel_distance_km IS NULL)
    OR
    (travel_coordinates_estimated = false)
  );

COMMENT ON COLUMN public.quotes.travel_distance_km IS
  'One-way Haversine distance, talent base to event. Internal only, not client-facing. NULL when the percentage fallback was used.';

COMMENT ON COLUMN public.quotes.travel_coordinates_estimated IS
  'True when coordinates were unavailable and travel was charged as a flat percentage of the performance fee. Internal only.';
