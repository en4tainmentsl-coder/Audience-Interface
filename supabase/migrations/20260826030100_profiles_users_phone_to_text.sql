-- profiles_users.phone was numeric, which cannot represent a phone number:
-- no '+' prefix, no leading zeros, no separators. Sri Lankan mobiles are
-- conventionally written 07X XXX XXXX, so numeric storage silently destroyed
-- the leading zero on essentially every local number.
--
-- It also broke venue signup outright: VenuePortal sent a string into the
-- numeric column, so the profile insert failed AFTER the auth user was created,
-- leaving an orphaned auth.users row that could not retry with the same email.
--
-- No CHECK constraint is added here. An E.164 format check must wait until the
-- write side is confirmed to normalise correctly, or signup breaks a second time.

alter table public.profiles_users
  alter column phone type text using phone::text;

-- Restore the '+' lost to numeric storage on existing rows.
update public.profiles_users
   set phone = '+' || phone
 where phone !~ '^\+';
