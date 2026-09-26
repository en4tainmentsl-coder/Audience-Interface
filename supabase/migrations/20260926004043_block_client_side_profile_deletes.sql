-- Profile rows must NEVER be hard-deleted from the client.
-- Deleting one cascades through talent_identity (NIC hash, KYC refs), talent_media,
-- payments, contracts, messages and more, destroying legal-hold data silently and
-- orphaning R2/Cloudinary objects. Verified behaviourally 2026-09-26: a talent with
-- no bookings could delete their own profiles_talent row and its talent_identity row.
-- The manage_own policies are FOR ALL, which included DELETE; the bookings FK only
-- blocked users who had ever had a booking.
-- Erasure is anonymise-in-place, performed by service_role. Nothing else deletes these.

revoke delete, truncate on public.profiles_talent  from anon, authenticated;
revoke delete, truncate on public.profiles_users   from anon, authenticated;
revoke delete, truncate on public.profiles_clients from anon, authenticated;
revoke delete, truncate on public.profiles_venues  from anon, authenticated;
revoke delete, truncate on public.profiles_admin   from anon, authenticated;
revoke delete, truncate on public.talent_identity  from anon, authenticated;